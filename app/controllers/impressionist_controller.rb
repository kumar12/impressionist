require 'digest/sha2'

module ImpressionistController
  extend ActiveSupport::Concern

  included do
    before_action :impressionist_app_filter
  end

  class_methods do
    def impressionist(opts = {})
      before_action { |c| c.impressionist_subapp_filter(opts) }
    end
  end

  def impressionist(obj, message = nil, opts = {})
    return unless should_count_impression?(opts)

    if obj.respond_to?("impressionable?")
      if unique_instance?(obj, opts[:unique])
        obj.impressions.create(associative_create_statement(message: message))
      end
    else
      raise "#{obj.class} is not impressionable!"
    end
  end

  def impressionist_app_filter
    @impressionist_hash = Digest::SHA2.hexdigest("#{Time.now.to_f}#{rand(10000)}")
  end

  def impressionist_subapp_filter(opts = {})
    return unless should_count_impression?(opts)

    actions = Array(opts[:actions]).map(&:to_s)
    if (actions.blank? || actions.include?(action_name)) && unique?(opts[:unique])
      Impression.create(direct_create_statement)
    end
  end

  protected

  def associative_create_statement(query_params = {})
    filter = if Rails::VERSION::MAJOR < 6
               ActionDispatch::Http::ParameterFilter.new(Rails.application.config.filter_parameters)
             else
               ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
             end

    query_params.reverse_merge!(
      controller_name: controller_name,
      action_name: action_name,
      user_id: user_id,
      request_hash: @impressionist_hash,
      session_hash: session_hash,
      ip_address: request.remote_ip,
      referrer: request.referer,
      params: filter.filter(params_hash)
    )
  end

  private

  def bypass
    Impressionist::Bots.bot?(request.user_agent)
  end

  def should_count_impression?(opts)
    !bypass && condition_true?(opts[:if]) && condition_false?(opts[:unless])
  end

  def condition_true?(condition)
    condition.present? ? conditional?(condition) : true
  end

  def condition_false?(condition)
    condition.present? ? !conditional?(condition) : true
  end

  def conditional?(condition)
    condition.is_a?(Symbol) ? send(condition) : condition.call
  end

  def unique_instance?(impressionable, unique_opts)
    unique_opts.blank? || !impressionable.impressions.where(unique_query(unique_opts, impressionable)).exists?
  end

  def unique?(unique_opts)
    unique_opts.blank? || check_impression?(unique_opts)
  end

  def check_impression?(unique_opts)
    impressions = Impression.where(unique_query(unique_opts - [:params]))
    check_unique_impression?(impressions, unique_opts)
  end

  def check_unique_impression?(impressions, unique_opts)
    impressions_present = impressions.exists?
    impressions_present && unique_opts.include?(:params) ? check_unique_with_params?(impressions) : !impressions_present
  end

  def check_unique_with_params?(impressions)
    impressions.none? { |impression| impression.params == params_hash }
  end

  def unique_query(unique_opts, impressionable = nil)
    full = direct_create_statement({}, impressionable)
    unique_opts.each_with_object({}) { |param, query| query[param] = full[param] }
  end

  def direct_create_statement(query_params = {}, impressionable = nil)
    query_params.reverse_merge!(
      impressionable_type: controller_name.singularize.camelize,
      impressionable_id: impressionable&.id || params[:id]
    )
    associative_create_statement(query_params)
  end

  def session_hash
    session["init"] = true if Rails::VERSION::MAJOR >= 4
    id = session.id.to_s rescue request.session_options[:id]
    id.is_a?(String) ? id : (id.respond_to?(:cookie_value) ? id.cookie_value : nil)
  end

  def params_hash
    request.params.except(:controller, :action, :id)
  end

  def user_id
    @current_user&.id || current_user&.id rescue nil
  end
end

# lib/impressionist/engine.rb
require 'rails'

module Impressionist
  class Engine < ::Rails::Engine
    attr_accessor :orm

    initializer 'impressionist.model' do
      @orm = Impressionist.orm
      include_orm
    end

    initializer 'impressionist.controller' do
      # Manually require the controller from within the gem
      require File.expand_path('../../../app/controllers/impressionist_controller.rb', __FILE__)

      ActiveSupport.on_load(:action_controller) do
        include ::ImpressionistController
      end
    end

    private

    def include_orm
      require "#{root}/app/models/impressionist/impressionable.rb"
      require "impressionist/models/#{orm}/impression.rb"
      require "impressionist/models/#{orm}/impressionist/impressionable.rb"
    end
  end
end

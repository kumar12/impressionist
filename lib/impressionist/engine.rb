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
      # ⬇ force eager loading of the controller module before referencing it
      require_relative '../../app/controllers/impressionist_controller'

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


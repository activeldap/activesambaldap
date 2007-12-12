module ActiveSambaLdap
  module Reloadable
    def self.included(base)
      super
      return unless Object.const_defined?(:Reloadable)
      base.class_eval do
        if ::Reloadable.const_defined?(:Deprecated)
          include ::Reloadable::Deprecated
        else
          include ::Reloadable::Subclasses
        end
      end
    end
  end
end

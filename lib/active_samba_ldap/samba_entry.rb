module ActiveSambaLdap
  module SambaEntry
    def samba_available?
      classes.include?(samba_object_class)
    end

    def remove_samba_availability
      remove_class(samba_object_class)
    end

    def ensure_samba_available
      add_class(samba_object_class)
    end

    def samba_object_class
      self.class.samba_object_class
    end

    private
    def assert_samba_available
      unless samba_available?
        raise NotSambaAavialableError.new(self)
      end
    end
  end
end

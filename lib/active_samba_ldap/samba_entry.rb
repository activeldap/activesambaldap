module ActiveSambaLdap
  module SambaEntry
    def samba_available?
      (samba_object_classes - classes).empty?
    end

    def remove_samba_availability
      remove_class(*samba_object_classes)
    end

    def ensure_samba_available
      add_class(*samba_object_classes)
    end

    def samba_object_class
      self.class.samba_object_classes
    end

    private
    def assert_samba_available
      return if samba4?
      unless samba_available?
        raise NotSambaAavialableError.new(self)
      end
    end
  end
end

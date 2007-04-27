module ActiveSambaLdap
  module SambaEntry
    private
    def assert_samba_available
      unless samba_available?
        raise NotSambaAavialableError.new(self)
      end
    end
  end
end

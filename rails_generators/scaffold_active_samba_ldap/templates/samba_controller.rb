class SambaController < ApplicationController
  def index
  end

  def populate
    @entries, options = ActiveSambaLdap::Base.populate
  end

  def purge
    ActiveSambaLdap::Base.purge
  end
end

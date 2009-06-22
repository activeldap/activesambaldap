class ScaffoldActiveSambaLdapGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.template("ldap.yml", File.join("config", "ldap.yml"))

      %w(user computer group unix_id_pool idmap ou dc).each do |component|
        m.template("#{component}.rb",
                   File.join("app", "models", "#{component}.rb"))
      end

      component = "samba"
      controller_class_name = "#{Inflector.camelize(component)}Controller"
      options = {:assigns => {:controller_class_name => controller_class_name}}

      m.template("#{component}_controller.rb",
                 File.join("app", "controllers", "#{component}_controller.rb"))
      m.template("#{component}_helper.rb",
                 File.join("app", "helpers", "#{component}_helper.rb"))
      m.directory(File.join("app", "views", component))
      %w(index populate purge).each do |action|
        m.template("#{component}_#{action}.rhtml",
                   File.join("app", "views", component, "#{action}.rhtml"),
                   options)
      end
    end
  end
end

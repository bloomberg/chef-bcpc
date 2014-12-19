
#/var/run/reboot-required

class RestartHandler < Chef::Handler
  include Chef::Mixin::ShellOut
  def report

    if File.exists?("/var/run/reboot-required")
      Chef::Log.warn('Rebooting system from Chef')
      # insert code here 
      shell_out!("shutdown -r 2 From chef")
    else
      Chef::Log.info('No reboot required')
    end
  end
end

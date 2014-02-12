require 'log4r'

require 'vagrant/util/busy'
require 'vagrant/util/network_ip'
require 'vagrant/util/platform'
require 'vagrant/util/retryable'
require 'vagrant/util/subprocess'

module VagrantPlugins
  module Parallels
    module Driver
      # Base class for all Parallels drivers.
      #
      # This class provides useful tools for things such as executing
      # PrlCtl and handling SIGINTs and so on.
      class Base
        # Include this so we can use `Subprocess` more easily.
        include Vagrant::Util::Retryable
        include Vagrant::Util::NetworkIP

        def initialize
          @logger = Log4r::Logger.new("vagrant::provider::parallels::base")

          # This flag is used to keep track of interrupted state (SIGINT)
          @interrupted = false

          # Set the path to prlctl
          @prlctl_path = "prlctl"
          @prlsrvctl_path = "prlsrvctl"

          @logger.info("CLI prlctl path: #{@prlctl_path}")
          @logger.info("CLI prlsrvctl path: #{@prlsrvctl_path}")
        end

        # Clears the shared folders that have been set on the virtual machine.
        def clear_shared_folders
        end

        # Creates a host only network with the given options.
        #
        # @param [Hash] options Options to create the host only network.
        # @return [Hash] The details of the host only network, including
        #   keys `:name`, `:ip`, and `:netmask`
        def create_host_only_network(options)
        end

        # Deletes the virtual machine references by this driver.
        def delete
        end

        # Deletes any host only networks that aren't being used for anything.
        def delete_unused_host_only_networks
        end

        # Enables network adapters on the VM.
        #
        # The format of each adapter specification should be like so:
        #
        # {
        #   :type     => :hostonly,
        #   :hostonly => "vboxnet0",
        #   :mac_address => "tubes"
        # }
        #
        # This must support setting up both host only and bridged networks.
        #
        # @param [Array<Hash>] adapters Array of adapters to enable.
        def enable_adapters(adapters)
        end

        # Execute a raw command straight through to VBoxManage.
        #
        # Accepts a :retryable => true option if the command should be retried
        # upon failure.
        #
        # Raises a VBoxManage error if it fails.
        #
        # @param [Array] command Command to execute.
        def execute_command(command)
        end

        # Exports the virtual machine to the given path.
        #
        # @param [String] path Path to the OVF file.
        # @yield [progress] Yields the block with the progress of the export.
        def export(path)
        end

        # Halts the virtual machine (pulls the plug).
        def halt
        end

        # Imports the VM from an OVF file.
        #
        # @param [String] ovf Path to the OVF file.
        # @return [String] UUID of the imported VM.
        def import(ovf)
        end

        # Parses given block (JSON string) to object
        def json(default=nil)
          data = yield
          JSON.parse(data) rescue default
        end

        # Returns the maximum number of network adapters.
        # TODO: Implement the usage!
        def max_network_adapters
          16
        end

        # Returns a list of bridged interfaces.
        #
        # @return [Hash]
        def read_bridged_interfaces
        end

        # Returns the guest tools version that is installed on this VM.
        #
        # @return [String]
        def read_guest_tools_version
        end

        # Returns a list of available host only interfaces.
        #
        # @return [Hash]
        def read_host_only_interfaces
        end

        # Returns the MAC address of the first network interface.
        #
        # @return [String]
        def read_mac_address
        end

        # Returns a list of network interfaces of the VM.
        #
        # @return [Hash]
        def read_network_interfaces
        end

        # Returns the current state of this VM.
        #
        # @return [Symbol]
        def read_state
        end

        # Returns a list of all UUIDs of virtual machines currently
        # known by VirtualBox.
        #
        # @return [Array<String>]
        def read_vms
        end

        # Sets the MAC address of the first network adapter.
        #
        # @param [String] mac MAC address without any spaces/hyphens.
        def set_mac_address(mac)
        end

        # Sets the VM name.
        #
        # @param [String] name New VM name.
        def set_name(name)
        end

        # Share a set of folders on this VM.
        #
        # @param [Array<Hash>] folders
        def share_folders(folders)
        end

        # Reads the SSH port of this VM.
        #
        # @param [Integer] expected Expected guest port of SSH.
        def ssh_port(expected)
        end

        # Starts the virtual machine.
        #
        # @param [String] mode Mode to boot the VM. Either "headless"
        #   or "gui"
        def start(mode)
        end

        # Suspend the virtual machine.
        def suspend
        end

        # Verifies that the driver is ready to accept work.
        #
        # This should raise a VagrantError if things are not ready.
        def verify!
        end

        # Checks if a VM with the given UUID exists.
        #
        # @return [Boolean]
        def vm_exists?(uuid)
        end

        # Execute the given subcommand for PrlCtl and return the output.
        def execute(*command, &block)
          # Get the options hash if it exists
          opts = {}
          opts = command.pop if command.last.is_a?(Hash)

          tries = opts[:retryable] ? 3 : 0

          # Variable to store our execution result
          r = nil

          retryable(:on => VagrantPlugins::Parallels::Errors::PrlCtlError, :tries => tries, :sleep => 1) do
            # If there is an error with PrlCtl, this gets set to true
            errored = false

            # Execute the command
            r = raw(*command, &block)

            # If the command was a failure, then raise an exception that is
            # nicely handled by Vagrant.
            if r.exit_code != 0
              if @interrupted
                @logger.info("Exit code != 0, but interrupted. Ignoring.")
              else
                errored = true
              end
            end

            # If there was an error running prlctl, show the error and the
            # output.
            if errored
              raise VagrantPlugins::Parallels::Errors::PrlCtlError,
                :command => command.inspect,
                :stderr  => r.stderr
            end
          end
          r.stdout
        end

        # Executes a command and returns the raw result object.
        def raw(*command, &block)
          int_callback = lambda do
            @interrupted = true
            @logger.info("Interrupted.")
          end

          # Append in the options for subprocess
          command << { :notify => [:stdout, :stderr] }

          # Get the utility to execute:
          # 'prlctl' by default and 'prlsrvctl' if it set as a first argument in command
          if command.first == :prlsrvctl
            cli = @prlsrvctl_path
            command.delete_at(0)
          else
            cli = @prlctl_path
          end

          Vagrant::Util::Busy.busy(int_callback) do
            Vagrant::Util::Subprocess.execute(cli, *command, &block)
          end
        end
      end
    end
  end
end
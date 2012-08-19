require 'multi_json'

require 'travis'
require 'travis/support'

$stdout.sync = true

module Travis
  class Tasks
    include Logging

    QUEUES = ['tasks', 'tasks.log']

    class << self
      def start
        setup
        new.subscribe
      end

      protected

        def setup
          Travis::Async.enabled = true
          Travis.config.update_periodically

          Travis::Exceptions::Reporter.start
          Travis::Notification.setup

          Travis::Amqp.config = Travis.config.amqp
          Travis::Mailer.setup
          # Travis::Features.start

          NewRelic.start if File.exists?('config/newrelic.yml')
        end
    end

    def subscribe
      info 'Subscribing to amqp ...'
      QUEUES.each do |queue|
        info "Subscribing to #{queue}"
        Travis::Amqp::Consumer.new(queue).subscribe(:ack => true, &method(:receive))
      end
    end

    def receive(message, payload)
      if payload = decode(payload)
        Travis.uuid = payload.delete('uuid')
        handle(*payload.values_at(%w(type data options)))
      end
    rescue Exception => e
      puts "!!!FAILSAFE!!! #{e.message}", e.backtrace
    ensure
      message.ack
    end

    protected

      def handle(task, data, options)
        timeout do
          type = "Travis::Task::#{task.camelize}".constantize
          task = type.new(data, options)
          task.run
        end
      end
      rescues :handle, :from => Exception

      def timeout(&block)
        Timeout::timeout(60, &block)
      end

      def decode(payload)
        MultiJson.decode(payload)
      rescue StandardError => e
        error "[#{Thread.current.object_id}] [decode error] payload could not be decoded with engine #{MultiJson.engine.to_s} (#{e.message}): #{payload.inspect}"
        nil
      end
  end
end


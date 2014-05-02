require 'action_mailer'

module Travis
  module Addons
    module Email
      module Mailer
        class Build < ActionMailer::Base

          helper Mailer::Helpers

          attr_reader :build, :commit, :repository, :jobs, :result_message

          def finished_email(data, recipients, broadcasts)
            data = data.deep_symbolize_keys

            @build      = Hashr.new(data[:build])
            @repository = Hashr.new(data[:repository])
            @commit     = Hashr.new(data[:commit])
            @jobs       = data[:jobs].map { |job| Hashr.new(job) }
            @broadcasts = Array(broadcasts).map { |broadcast| Hashr.new(broadcast) }
            @result_message = ::Travis::Addons::Util::ResultMessage.new(@build)

            headers['X-MC-Tags'] = Travis.env
            headers['In-Reply-To'] = "<%s+%s+%s@travis-ci.org>" % [ repository.slug, build.id, result_message.short.downcase ]

            mail(from: from, to: recipients, subject: subject, template_path: 'build')
          end

          def url_options
            nil
          end

          private

            def subject
              "[#{result_message.short}] #{repository.slug}##{build.number} (#{commit.branch} - #{commit.sha[0..6]})"
            end

            def from
              "\"Travis CI\" <#{from_email % result_message.short.downcase}>"
            end

            def from_email
              Travis.config.email.from || "notifications@#{Travis.config.host}"
            end
        end
      end
    end
  end
end

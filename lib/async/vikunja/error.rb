module Async
  module Vikunja
    class Error < StandardError
    end

    class Failure < Error
      def self.for(response)
        problem = self.problem_for(response.read)

        self.new(
          response.status.to_s + ": " + self.summary_of(problem),
          status: response.status,
          problem: problem,
          retry_after: response.headers["retry-after"],
        )
      end

      def self.problem_for(payload)
        case payload
        in Hash => problem
          problem
        else
          {detail: payload.to_s}
        end
      end

      def self.summary_of(problem)
        problem[:title] || problem[:detail] || problem.inspect
      end

      def initialize(message, status:, problem: {}, retry_after: nil)
        super(message)

        @status = status
        @problem = problem
        @retry_after = retry_after
      end

      attr :status
      attr :problem
      attr :retry_after

      def code = @problem[:code]

      def title = @problem[:title]

      def detail = @problem[:detail]

      def errors = Array(@problem[:errors])
    end
  end
end

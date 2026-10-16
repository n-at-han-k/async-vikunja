require_relative "page"

module Async
  module Vikunja
    class Reaction < Representation
      def created = self.value[:created]

      def user = self.nested(User, self.value[:user])
    end

    module Reactions
      def reactions(entitykind, entityid) = Representation.new(self.with(path: Vikunja.escape(entitykind) + "/" + Vikunja.escape(entityid) + "/reactions"))

      def add_reaction(entitykind, entityid, payload) = self.submit(Reaction, self.with(path: Vikunja.escape(entitykind) + "/" + Vikunja.escape(entityid) + "/reactions"), payload)

      def remove_reaction(entitykind, entityid, payload) = self.submit(Representation, self.with(path: Vikunja.escape(entitykind) + "/" + Vikunja.escape(entityid) + "/reactions/delete"), payload)
    end
  end
end

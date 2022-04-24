defmodule Neo4jExplaygroundTest.BasicTest do
  use ExUnit.Case

  alias Playground.Bracket2

  describe "neo4j" do
    test "works" do
      conn = Bolt.Sips.conn()

      conn
      |> Bolt.Sips.query!("
        CREATE (p: Person)
        RETURN p
      ")
      |> Bolt.Sips.Response.first()
      |> IO.inspect()

      #Bracket2.test(5)
    end
  end
end

defmodule Neo4jExplaygroundTest.BasicTest do
  use ExUnit.Case

  describe "neo4j" do
    test "works" do
      conn = Bolt.Sips.conn()

      conn
      |> Bolt.Sips.query!("return 1 as n")
      |> Bolt.Sips.Response.first()
      |> IO.inspect()
    end
  end
end

defmodule Neo4jExplaygroundTest.BasicTest do
  use ExUnit.Case

  alias Playground.Bracket

  describe "neo4j" do
    test "works" do
      conn = Bolt.Sips.conn()

      Bolt.Sips.query!(conn, "
        MATCH (n)
        DETACH DELETE n
      ")

      # Bolt.Sips.query!(conn, "
      #   CREATE (m1: Match {tournament_id: 1})-[:LEFT]->(m2: Match {tournament_id: 1})-[:LEFT]->(e1: Entry {tournament_id: 1, name: 'a'})
      #   CREATE (m2)-[:RIGHT]->(e2: Entry {tournament_id: 1, name: 'b'})
      #   CREATE (m1)-[:RIGHT]->(e3: Entry {tournament_id: 1, name: 'c'})
      # ")

      5
      |> Bracket.test(1)
      |> Bracket.store_parsed_match_list()

      8
      |> Bracket.test(1)
      |> Bracket.store_parsed_match_list()
    end
  end
end

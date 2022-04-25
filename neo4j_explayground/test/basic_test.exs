defmodule Neo4jExplaygroundTest.BasicTest do
  use ExUnit.Case

  alias Playground.Bracket

  describe "neo4j" do
    test "store works" do
      Bolt.Sips.query!(Bolt.Sips.conn(), "MATCH (n) DETACH DELETE n")

      tournament_id = 1

      5
      |> Bracket.test(tournament_id)
      |> Bracket.store_parsed_match_list()

      # 8
      # |> Bracket.test(1)
      # |> Bracket.store_parsed_match_list()

      tournament_id
      |> Bracket.load_match_list()
      |> IO.inspect()
    end
  end
end

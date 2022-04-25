defmodule Playground.Bracket do
  defmodule Entry do
    @type t() :: %__MODULE__{
      name: String.t(),
      tournament_id: integer()
    }
    defstruct [
      :name,
      :tournament_id
    ]
  end

  defmodule Match do
    @type t() :: %__MODULE__{
      round: integer(),
      index: integer(),
      childlen: integer(),
      tournament_id: integer(),
      left: Entry | Match | nil,
      right: Entry | Match | nil,
    }

    defstruct [
      round: 1,
      index: nil,
      childlen: 0,
      tournament_id: 0,
      left: nil,
      right: nil
    ]

    @spec insert(Match.t, Entry.t, integer()) :: Match.t()
    def insert(match = %Match{}, entry = %Entry{}, tournament_id) do
      case [match.left, match.right] do
        [nil, nil] ->
           match |> Map.replace(:left, entry)
        [%Entry{}, nil] ->
          match |> Map.replace(:right, entry)
        [ml = %Entry{}, mr = %Entry{}] ->
          match
          |> Map.replace(:left, %Match{round: match.round+1, index: 0, left: ml, right: mr, tournament_id: tournament_id})
          |> Map.replace(:right, entry)
        [%Match{}, mr = %Entry{}] ->
          match.right |> put_in(%Match{round: match.round+1, index: 0, left: mr, right: entry, tournament_id: tournament_id})
        [ml = %Match{}, mr = %Match{}] ->
          ml_size = Match.count_children(ml)
          mr_size = Match.count_children(mr)
          cond do
            ml_size <= mr_size ->
              match |> Map.replace(:left, insert(ml, entry, tournament_id))
            ml_size > mr_size ->
              match |> Map.replace(:right, insert(mr, entry, tournament_id))
          end
      end
    end

    def count_children(match = %Match{}, count \\ 0) do
      Enum.reduce([match.left, match.right], count, fn e, acc ->
        case e do
          x = %Match{} -> count_children(x, acc)
          %Entry{} -> acc + 1
        end
      end)
    end
  end

  def load_match_list(tournament_id) do
    root_node = Bolt.Sips.conn()
      |> Bolt.Sips.query!("
        MATCH (root_match: Match)
        WHERE root_match.tournament_id = #{tournament_id} AND root_match.is_root
        RETURN root_match
      ")
      |> Bolt.Sips.Response.first()
      |> Map.get("root_match")

    __MODULE__.load_match_list(tournament_id, root_node, %Match{round: root_node.properties["round"], tournament_id: tournament_id})
  end

  def load_match_list(tournament_id, parent_node, acc_match) do
    # NOTE: LEFTを確認してRIGHTを確認する

    acc_match = load_left_node(tournament_id, parent_node, acc_match)
    acc_match = load_right_node(tournament_id, parent_node, acc_match)

    acc_match
  end

  defp load_left_node(tournament_id, parent_node, acc_match) do
    left_node = Bolt.Sips.conn()
      |> Bolt.Sips.query!("
        MATCH (parent_match: Match)-[:LEFT]->(node)
        WHERE id(parent_match) = #{parent_node.id}
        RETURN node
      ")
      |> Bolt.Sips.Response.first()
      |> Map.get("node")

    if is_nil(left_node) do
      acc_match
    else
      cond do
        Enum.member?(left_node.labels, "Match") ->
          # 再帰したmatchをleftにつなげてやればいい
          acc = __MODULE__.load_match_list(tournament_id, left_node, acc_match)
          acc = Map.put(acc, :round, left_node.properties["round"])
          Map.put(acc_match, :left, acc)
        Enum.member?(left_node.labels, "Entry") ->
          # entryをそのまま返してやればいい
          Map.put(acc_match, :left, %Entry{name: left_node.properties["name"], tournament_id: left_node.properties["tournament_id"]})
      end
    end
  end

  defp load_right_node(tournament_id, parent_node, acc_match) do
    right_node = Bolt.Sips.conn()
      |> Bolt.Sips.query!("
        MATCH (parent_match: Match)-[:RIGHT]->(node)
        WHERE id(parent_match) = #{parent_node.id}
        RETURN node
      ")
      |> Bolt.Sips.Response.first()
      |> Map.get("node")

    if is_nil(right_node) do
      acc_match
    else
      cond do
        Enum.member?(right_node.labels, "Match") ->
          # 再帰したmatchをleftにつなげてやればいい
          acc = __MODULE__.load_match_list(tournament_id, right_node, acc_match)
          acc = Map.put(acc, :round, right_node.properties["round"])
          Map.put(acc_match, :right, acc)
        Enum.member?(right_node.labels, "Entry") ->
          # entryをそのまま返してやればいい
          Map.put(acc_match, :right, %Entry{name: right_node.properties["name"], tournament_id: right_node.properties["tournament_id"]})
      end
    end
  end

  def store_parsed_match_list(%Match{} = match) do
    # NOTE: rootのノードを作成する箇所
    root_node = Bolt.Sips.conn()
      |> Bolt.Sips.query!("
        CREATE (m: Match {round: #{match.round}, tournament_id: #{match.tournament_id}, is_root: true})
        RETURN m
      ")
      |> Bolt.Sips.Response.first()
      |> Map.get("m")

    __MODULE__.store_parsed_match_list(match, root_node)
  end
  def store_parsed_match_list(%Match{} = match, parent_node) do
    case match do
      %Match{left: match} -> create_child_match_node(match, parent_node, :left)
    end

    case match do
      %Match{right: match} -> create_child_match_node(match, parent_node, :right)
    end
  end

  defp create_child_match_node(%Match{} = match, parent_node, left_or_right_key) do
    key = left_or_right_relation_key(left_or_right_key)

    new_node = Bolt.Sips.conn()
      |> Bolt.Sips.query!("
        MATCH (parent_match: Match)
        WHERE id(parent_match) = #{parent_node.id}

        CREATE (parent_match)-[#{key}]->(m: Match {round: #{match.round}, tournament_id: #{match.tournament_id}})
        RETURN m
      ")
      |> Bolt.Sips.Response.first()
      |> Map.get("m")

    __MODULE__.store_parsed_match_list(match, new_node)
  end

  defp create_child_match_node(%Entry{} = entry, parent_node, left_or_right_key) do
    key = left_or_right_relation_key(left_or_right_key)

    Bolt.Sips.conn()
    |> Bolt.Sips.query!("
      MATCH (parent_match: Match)
      WHERE id(parent_match) = #{parent_node.id}

      CREATE (parent_match)-[#{key}]->(e: Entry {tournament_id: #{entry.tournament_id}, name: '#{entry.name}'})
    ")
  end

  defp left_or_right_relation_key(:left),  do: ":LEFT"
  defp left_or_right_relation_key(:right), do: ":RIGHT"

  def test(size, tournament_id) do
    ?a..?z
    |> Enum.map(&<<&1 :: utf8>>)
    |> Enum.take(size)
    |> Enum.map(&%Entry{name: &1, tournament_id: tournament_id})
    |> Enum.reduce(%Match{tournament_id: tournament_id}, &Match.insert(&2, &1, tournament_id))
  end

  defp flat_match(match, acc \\ []) do
    acc =
    case match do
      %Match{left: %Match{} = match}  -> acc ++ [match]
      _ -> acc
    end
    case match do
      %Match{right: %Match{} = match}  -> acc ++ [match]
      _ -> acc
    end
  end

  defp find(match, target_round, acc \\ []) do
    acc =
      case match do
        %Match{round: r} when r == target_round -> acc ++ [match]
        _ -> acc
      end

    acc =
    case match do
      %Match{left: match} when not is_nil(match) -> find(match, target_round, acc)
      _ -> acc
    end

    case match do
      %Match{right: match} when not is_nil(match) -> find(match, target_round, acc)
      _ -> acc
    end
  end

  defp find_v2(match, target_round, acc \\ []) do
    acc =
    case match do
      %Match{round: r} when r == target_round -> acc ++ [match]
      _ -> acc
    end

    acc =
    case match do
      %Match{left: %Match{} = match} when match.round <= target_round -> find_v2(match, target_round, acc)
      _ -> acc
    end
    case match do
      %Match{right: %Match{} = match} when match.round <= target_round -> find_v2(match, target_round, acc)
      _ -> acc
    end
  end

end

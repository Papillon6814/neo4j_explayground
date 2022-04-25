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

  def store_parsed_match_list(%Match{} = match) do
    # NOTE: rootのノードを作成する箇所
    root_node = Bolt.Sips.conn()
      |> Bolt.Sips.query!("
        CREATE (m: Match {round: #{match.round}, tournament_id: #{match.tournament_id}})
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

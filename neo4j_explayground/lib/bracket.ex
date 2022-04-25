defmodule Playground.Bracket do
  defmodule Entry do
    @type t() :: %__MODULE__{
      name: String.t
    }
    defstruct [
      :name
    ]
  end

  defmodule Match do
    @type t() :: %__MODULE__{
      round: integer(),
      index: integer(),
      childlen: integer(),
      left: Entry | Match | nil,
      right: Entry | Match | nil,
    }
    defstruct [
      round: 1,
      index: nil,
      childlen: 0,
      left: nil,
      right: nil
    ]

    def insert(match = %Match{}, entry = %Entry{}) do
      case [match.left, match.right] do
        [nil, nil] ->
           match |> Map.replace(:left, entry)
        [%Entry{}, nil] ->
          match |> Map.replace(:right, entry)
        [ml = %Entry{}, mr = %Entry{}] ->
          match
          |> Map.replace(:left, %Match{round: match.round+1, index: 0, left: ml, right: mr})
          |> Map.replace(:right, entry)
        [%Match{}, mr = %Entry{}] ->
          match.right |> put_in(%Match{round: match.round+1, index: 0, left: mr, right: entry})
        [ml = %Match{}, mr = %Match{}] ->
          ml_size = Match.count_children(ml)
          mr_size = Match.count_children(mr)
          cond do
            ml_size <= mr_size ->
              match |> Map.replace(:left, insert(ml, entry))
            ml_size > mr_size ->
              match |> Map.replace(:right, insert(mr, entry))
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


  def test(size) do
    # entrys = Enum.to_list(1..size)
    entrys = ?a..?z
      |> Enum.map(fn x -> <<x :: utf8>> end)
      |> Enum.take(size)

    entrys = Enum.map(entrys, fn n -> %Entry{name: n} end)
    bracket = Enum.reduce(entrys, %Match{}, fn e, m ->
      m |> Match.insert(e)
    end)
    |> IO.inspect()

    # v1 = bracket |> find(4)
    # v2 = bracket |> find_v2(4)

    # bracket |> flat_match()
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

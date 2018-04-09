defmodule EctoQueryString do
  import Ecto.Query
  # /"!@$#*()-_;:',.~[]"

  def query(query, ""), do: query(query, %{})
  def query(query, nil), do: query(query, %{})

  def query(query, %{} = params) do
    Enum.reduce(params, query, &dynamic_segment/2)
  end

  def query(query, querystring) when is_binary(querystring) do
    params = URI.decode_query(querystring)
    query(query, params)
  end

  def queryable?(field, query) do
    fields = schema_fields(query)

    if(Enum.find(fields, &Kernel.==(&1, field))) do
      String.to_atom(field)
    end
  end

  def selectable(fields, query) do
    fields =
      fields
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    schema_fields = schema_fields(query)

    fields = for field <- fields, field && field in schema_fields, do: field
    Enum.map(fields, &String.to_atom/1)
  end

  def schema_fields(query) do
    query.from
    |> elem(1)
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> Map.keys()
    |> Enum.map(&to_string/1)
  end

  defp dynamic_segment({"@", value}, acc) do
    attrs = selectable(value, acc)
    from(acc, select: ^attrs)
  end

  defp dynamic_segment({"...", value}, acc) do
    case String.split(value, ":") do
      [".", "."] -> acc
      [".", max] -> from(acc, limit: ^max)
      [min, "."] -> from(acc, offset: ^min)
      [min, max] -> from(acc, offset: ^min, limit: ^max)
      :else -> acc
    end
  end

  defp dynamic_segment({"..." <> key, value}, acc) do
    if new_key = queryable?(key, acc) do
      dynamic =
        case String.split(value, ":") do
          [".", "."] -> acc
          [".", max] -> dynamic([q], field(q, ^new_key) < ^max)
          [min, "."] -> dynamic([q], field(q, ^new_key) > ^min)
          [min, max] -> dynamic([q], field(q, ^new_key) > ^min and field(q, ^new_key) < ^max)
          :else -> acc
        end

      from(acc, where: ^dynamic)
    else
      acc
    end
  end

  defp dynamic_segment({"$asc", values}, acc) do
    order_values = selectable(values, acc)
    from(acc, order_by: ^order_values)
  end

  defp dynamic_segment({"$desc", values}, acc) do
    order_values =
      values
      |> selectable(acc)
      |> Enum.map(fn value -> {:desc, value} end)

    from(acc, order_by: ^order_values)
  end

  defp dynamic_segment({"i~" <> key, value}, acc) do
    value = String.replace(value, "*", "%")
    new_key = queryable?(key, acc)
    dynamic = dynamic([q], ilike(field(q, ^new_key), ^value))
    from(acc, where: ^dynamic)
  end

  defp dynamic_segment({"~" <> key, value}, acc) do
    value = String.replace(value, "*", "%")
    new_key = queryable?(key, acc)
    dynamic = dynamic([q], like(field(q, ^new_key), ^value))
    from(acc, where: ^dynamic)
  end

  defp dynamic_segment({"!" <> key, value}, acc) do
    value = String.split(value, ",")
    new_key = queryable?(key, acc)

    case {new_key, value} do
      {nil, _} ->
        acc

      {_, nil} ->
        acc

      {key, [value]} ->
        from(acc, where: ^dynamic([query], field(query, ^key) != ^value))

      {key, value} when is_list(value) ->
        from(acc, where: ^dynamic([query], field(query, ^key) not in ^value))
    end
  end

  defp dynamic_segment({"/!" <> key, value}, acc) do
    value = String.split(value, ",")
    new_key = queryable?(key, acc)

    case {new_key, value} do
      {nil, _} ->
        acc

      {_, nil} ->
        acc

      {key, [value]} ->
        from(acc, or_where: ^dynamic([query], field(query, ^key) != ^value))

      {key, value} when is_list(value) ->
        from(acc, or_where: ^dynamic([query], field(query, ^key) not in ^value))
    end
  end

  defp dynamic_segment({"/" <> key, value}, acc) do
    value = String.split(value, ",")
    new_key = queryable?(key, acc)

    case {new_key, value} do
      {nil, _} ->
        acc

      {_, nil} ->
        acc

      {key, [value]} ->
        from(acc, or_where: ^dynamic([query], field(query, ^key) == ^value))

      {key, value} when is_list(value) ->
        from(acc, or_where: ^dynamic([query], field(query, ^key) in ^value))
    end
  end

  defp dynamic_segment({key, value}, acc) do
    value = String.split(value, ",")
    new_key = queryable?(key, acc)

    case {new_key, value} do
      {nil, _} ->
        acc

      {_, nil} ->
        acc

      {key, [value]} ->
        from(acc, where: ^dynamic([query], field(query, ^key) == ^value))

      {key, value} when is_list(value) ->
        from(acc, where: ^dynamic([query], field(query, ^key) in ^value))
    end
  end
end

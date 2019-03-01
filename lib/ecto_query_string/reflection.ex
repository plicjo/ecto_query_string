defmodule EctoQueryString.Reflection do
  @spec source_schema(Ecto.Query) :: Ecto.Schema
  def source_schema(query) do
    query.from.source |> elem(1)
  end

  @spec schema_fields(Ecto.Schema) :: list(:binary)
  def schema_fields(schema) do
    schema.__schema__(:fields)
    |> Enum.map(&to_string/1)
  end

  @spec has_field?(Ecto.Schema, :binary) :: :boolean
  def has_field?(schema, field_name) when is_binary(field_name) do
    list = schema_fields(schema)

    field_name in list
  end

  @spec field(Ecto.Schema, :binary) :: :atom
  def field(schema, field_name) when is_binary(field_name) do
    if has_field?(schema, field_name), do: String.to_atom(field_name)
  end

  @spec has_assoc?(Ecto.Schema, :binary) :: :boolean
  def has_assoc?(schema, assoc_name) when is_binary(assoc_name) do
    list =
      schema.__schema__(:associations)
      |> Enum.map(&to_string/1)

    assoc_name in list
  end

  @spec assoc_schema(Ecto.Schema, :binary) :: Ecto.Schema
  def assoc_schema(schema, assoc_name) when is_binary(assoc_name) do
    if has_assoc?(schema, assoc_name) do
      assoc = String.to_atom(assoc_name)
      schema.__schema__(:association, assoc).related
    end
  end
end

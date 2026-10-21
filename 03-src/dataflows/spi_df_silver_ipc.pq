// Dataflow:    spi_df_silver_ipc
// Layer:       Silver
// Source:      spi_lakehouse.spi_bronze_ipc_raw
// Destination: spi_lakehouse.spi_silver_ipc_cleaned  (Replace)
// Purpose:     Filter to Índice and 3 regions, map region labels to the
//              dimension vocabulary, parse periodo, cast decimal comma.

let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "49d06868-a854-4e7b-840b-3d66fba1d24a"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "9eab38c5-a0f9-48df-9f02-198c0ad250f6"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "spi_bronze_ipc_raw", ItemKind = "Table"]}[Data],
  #"Filtered rows" = Table.SelectRows(#"Navigation 2", each ([comunidades_y_ciudades_autonomas] = "09 Cataluña" or [comunidades_y_ciudades_autonomas] = "13 Madrid, Comunidad de" or [comunidades_y_ciudades_autonomas] = "Nacional") and ([tipo_de_dato] = "Índice") and ([total] <> null)),
  #"Removed columns" = Table.RemoveColumns(#"Filtered rows", {"tipo_de_dato", "_ingestion_timestamp", "_source_file"}),
  #"Replaced value" = Table.ReplaceValue(#"Removed columns", ",", ".", Replacer.ReplaceText, {"total"}),
  #"Split column by delimiter" = Table.SplitColumn(#"Replaced value", "periodo", Splitter.SplitTextByDelimiter("M"), {"periodo.1", "periodo.2"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Split column by delimiter", {{"periodo.1", Int64.Type}, {"periodo.2", Int64.Type}, {"total", type number}}),
  #"Renamed columns" = Table.RenameColumns(#"Changed column type", {{"comunidades_y_ciudades_autonomas", "region_name"}, {"grupos_ecoicop", "indicator_category"}, {"periodo.1", "year"}, {"periodo.2", "month"}, {"total", "indicator_value"}}),
  #"Inserted conditional column" = Table.AddColumn(#"Renamed columns", "Custom", each if [region_name] = "09 Cataluña" then "Cataluña" else if [region_name] = "13 Madrid, Comunidad de" then "Madrid" else [region_name]),
  #"Reordered columns" = Table.ReorderColumns(#"Inserted conditional column", {"region_name", "Custom", "indicator_category", "year", "month", "indicator_value"}),
  #"Removed columns 1" = Table.RemoveColumns(#"Reordered columns", {"region_name"}),
  #"Renamed columns 1" = Table.RenameColumns(#"Removed columns 1", {{"Custom", "region_name"}}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Renamed columns 1", {{"region_name", type text}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type 1", "domain", each "Consumer Prices"), {{"domain", type text}})
in
  #"Added custom"
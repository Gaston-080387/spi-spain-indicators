// Dataflow:    spi_df_gold_ipc
// Layer:       Gold
// Source:      spi_lakehouse.spi_silver_ipc_cleaned
// Destination: spi_warehouse.dbo.spi_fact_indicators  (Append)
// Precondition: DELETE FROM dbo.spi_fact_indicators WHERE source_key = 1
//               (run by scr_delete_gold_ipc in spi_pl_gold — ADR-010, ADR-018)
// Reference queries (no destination): spi_dim_indicator, spi_dim_region
//               read from spi_warehouse; M in spi_df_gold_ipc__spi_dim_indicator.pq
//               and spi_df_gold_ipc__spi_dim_region.pq.

let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "49d06868-a854-4e7b-840b-3d66fba1d24a"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "9eab38c5-a0f9-48df-9f02-198c0ad250f6"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "spi_silver_ipc_cleaned", ItemKind = "Table"]}[Data],
  #"Merged queries" = Table.NestedJoin(#"Navigation 2", {"indicator_category", "domain"}, spi_dim_indicator, {"indicator_category", "domain"}, "spi_dim_indicator", JoinKind.LeftOuter),
  #"Expanded spi_dim_indicator" = Table.ExpandTableColumn(#"Merged queries", "spi_dim_indicator", {"indicator_key"}, {"indicator_key"}),
  #"Merged queries 1" = Table.NestedJoin(#"Expanded spi_dim_indicator", {"region_name"}, spi_dim_region, {"region_name"}, "spi_dim_region", JoinKind.LeftOuter),
  #"Expanded spi_dim_region" = Table.ExpandTableColumn(#"Merged queries 1", "spi_dim_region", {"region_key"}, {"region_key"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded spi_dim_region", "calendar_key", each [year] * 100 + [month]), {{"calendar_key", Int64.Type}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "source_key", each 1), {{"source_key", Int64.Type}}),
  #"Removed other columns" = Table.SelectColumns(#"Added custom 1", {"indicator_key", "region_key", "calendar_key", "source_key", "indicator_value"})
in
  #"Removed other columns"
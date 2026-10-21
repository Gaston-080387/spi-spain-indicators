// Dataflow:    spi_df_gold_ipc
// Query:       spi_dim_indicator (reference query)
// Layer:       Gold
// Source:      spi_warehouse.dbo.spi_dim_indicator
// Destination: none (read-only lookup; joined by the fact query in spi_df_gold_ipc.pq)
// Rebuild:     replace workspaceId and warehouseId with the new workspace's IDs,
//              or re-create the query by navigating to spi_warehouse > dbo > spi_dim_indicator.
// Exported from the trial workspace on 2026-10-19 (Advanced editor).

let
  Source = Fabric.Warehouse(null),
  Navigation = Source{[workspaceId = "49d06868-a854-4e7b-840b-3d66fba1d24a"]}[Data],
  #"Navigation 1" = Navigation{[warehouseId = "798e8494-dd44-4996-8212-44adb3661863"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Schema = "dbo", Item = "spi_dim_indicator"]}[Data]
in
  #"Navigation 2"

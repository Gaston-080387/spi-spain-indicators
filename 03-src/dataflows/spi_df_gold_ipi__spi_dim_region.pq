// Dataflow:    spi_df_gold_ipi
// Query:       spi_dim_region (reference query)
// Layer:       Gold
// Source:      spi_warehouse.dbo.spi_dim_region
// Destination: none (read-only lookup; joined by the fact query in spi_df_gold_ipi.pq)
// Rebuild:     replace workspaceId and warehouseId with the new workspace's IDs,
//              or re-create the query by navigating to spi_warehouse > dbo > spi_dim_region.
// Exported from the trial workspace on 2026-10-19 (Advanced editor).

let
  Source = Fabric.Warehouse(null),
  Navigation = Source{[workspaceId = "bbffcd8e-0f61-436d-bee8-eac2d26d38b2"]}[Data],
  #"Navigation 1" = Navigation{[warehouseId = "bffbd9ed-33ad-4f34-a44a-18669a655853"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Schema = "dbo", Item = "spi_dim_region"]}[Data]
in
  #"Navigation 2"

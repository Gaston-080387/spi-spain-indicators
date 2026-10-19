# Rebuild checklist — hard-coded IDs

Started 2026-10-15. To become the rebuild runbook after 20 Oct.

Every ID below belongs to the current workspace. A rebuild in a new
workspace or capacity gives each item a new ID, so each occurrence must
be replaced before the file is pasted or run. Built from a scan of
`03-src/` on 2026-10-15.

Order matters: an ID can only be replaced once the item it points to
exists. Create the Lakehouse, Warehouse, connections, notebooks and
dataflows first, then the per-source pipelines, then the layer
pipelines, then `spi_pl_master`.

---

## 0. Before trial expiry (~2026-10-20)

Things that exist only in the trial workspace. Lost at expiry if not
captured.

- [x] **Export the Gold dataflows' reference queries.** (2026-10-19) `spi_df_gold_ipc`
      and `spi_df_gold_ipi` each hold two reference queries,
      `spi_dim_indicator` and `spi_dim_region` (read from
      `spi_warehouse`), that the `.pq` exports leave out. Both fact
      queries join on them. Export their M into the repo.
- [x] **Fill `03-src/dataflows/destinations.md`.** (2026-10-19, partial: see file) Every `[TO CHECK]`,
      read off each query's Data destination settings in Fabric.
- [x] **Check the Azure SQL firewall.** (2026-10-19: "Allow Azure services" is on, so Fabric in any region is admitted; IP rules are for the author's machine only.) On `spi-sqlserver-gb`,
      Networking: is "Allow Azure services and resources to access this
      server" on? If Fabric is admitted by IP rules instead, the rebuilt
      workspace in Sweden Central will connect from other addresses (§8).
- [ ] **Save the Power BI semantic model and report as PBIP** into
      `03-src/power-bi/`. The Direct Lake model exists only in the trial
      workspace.

## Creating the items

- [ ] **Keep every item name.** Names are references too:
      `dbo.spi_sp_gold_load` reads Silver as `spi_lakehouse.dbo.<table>`;
      `spi_nb_gold_refresh_sql_endpoint` resolves the Lakehouse by name
      (`LAKEHOUSE_NAME = "spi_lakehouse"`); pipelines reference
      `spi_warehouse` by name in their connection settings.
- [ ] **Create `spi_lakehouse` without Lakehouse schemas.** The notebooks
      write to `…/Tables/<table>`, with no `dbo/` segment (§6). A
      schema-enabled Lakehouse puts tables under `Tables/dbo/`. Check the
      schemas option in the creation dialog; its default is unverified.
- [ ] **Notebooks: check the runtime after import.** The repo notebooks
      carry the Python-runtime kernel metadata (`jupyter_python`, since
      2026-10-16). Confirm each opens on Python, not PySpark (ADR-012).

---

## 1. Workspace ID

`bbffcd8e-0f61-436d-bee8-eac2d26d38b2`

- [ ] All pipeline JSONs except `spi_pl_master` (13 of 14,
      `03-src/pipelines/`): `workspaceId` in every Script, Lookup, Copy,
      Notebook and Dataflow activity. `spi_pl_master` has none.
- [ ] The six notebooks' OneLake URIs, and the default-lakehouse
      metadata of all seven notebooks (§6).
- [ ] The four IPC/IPI dataflows' M (§9).

## 2. Warehouse `spi_warehouse`

| Field | Current value | In |
|---|---|---|
| `artifactId` | `bffbd9ed-33ad-4f34-a44a-18669a655853` | All pipeline JSONs except `spi_pl_master` (13) |
| `endpoint` | `s75vfahvn26u3ixeltcyscwbvy-r3g77o3bb5wuhpxi5lbne3jywi.datawarehouse.fabric.microsoft.com` | All pipeline JSONs except `spi_pl_master` (13) |
| connection | `e22a81cb-07ae-4539-8765-fc89bcb0b94d` | `spi_pl_bronze`, `spi_pl_silver`, `spi_pl_gold` (Lookup); `spi_pl_bronze_energy` / `_construction` / `_tax`, `spi_pl_silver_energy` / `_construction` / `_tax` (Script) |

- [ ] `artifactId`
- [ ] `endpoint`
- [ ] connection

Note: `spi_pl_bronze_ipc` / `_ipi` and `spi_pl_silver_ipc` / `_ipi`
reference the Warehouse in their Script activities through
`linkedService` with no connection ID. `spi_pl_gold`'s Script
activities use the same shape. Its Lookup does have the connection ID.

## 3. Notebook IDs (`notebookId` in Notebook activities)

| Notebook | Current ID | Pipeline |
|---|---|---|
| `spi_nb_bronze_energy` | `f9650a1e-284a-4215-bf6b-165b80612e8b` | `spi_pl_bronze_energy` |
| `spi_nb_bronze_construction` | `8342eb88-69bc-4ec4-b606-5ae12c436649` | `spi_pl_bronze_construction` |
| `spi_nb_bronze_tax` | `6937abd8-f9e1-4419-a4ff-7dbebfd134b3` | `spi_pl_bronze_tax` |
| `spi_nb_silver_energy` | `961c215d-868e-4c15-85c6-e2a33161b54c` | `spi_pl_silver_energy` |
| `spi_nb_silver_construction` | `5cc35d40-ff8a-4f25-971f-78ac8e1d59ea` | `spi_pl_silver_construction` |
| `spi_nb_silver_tax` | `58d57fc9-0237-4143-9e63-5e65256e10ec` | `spi_pl_silver_tax` |
| `spi_nb_gold_refresh_sql_endpoint` | `db02c520-4b6f-4c6c-a654-ab60e499fa5b` | `spi_pl_gold` |

- [ ] All seven

## 4. Dataflow IDs (`dataflowId` in Dataflow activities)

| Dataflow | Current ID | Pipeline |
|---|---|---|
| `spi_df_silver_ipc` | `fcf4c859-c17b-463f-a14e-bec307749f23` | `spi_pl_silver_ipc` |
| `spi_df_silver_ipi` | `46ea17b3-645b-4ad2-9c5e-85ca517f4522` | `spi_pl_silver_ipi` |
| `spi_df_gold_ipc` | `6cb21ab8-9fb9-427b-bcb0-62a7e66cdbc3` | `spi_pl_gold` |
| `spi_df_gold_ipi` | `5ec5cbee-80a6-45d2-aa7d-c2e51124cc53` | `spi_pl_gold` |

`spi_df_gold_dimensions` is not referenced by any pipeline.

- [ ] All four

## 5. Invoked pipeline IDs (`pipeline.referenceName` in Invoke pipeline (Legacy))

Each is the invoked pipeline's `objectId`.

| Layer pipeline | Activity | Invokes | Current ID |
|---|---|---|---|
| `spi_pl_bronze` | `inv_bronze_ipc` | `spi_pl_bronze_ipc` | `9795a868-245d-4922-a301-add0c9a12981` |
| | `inv_bronze_ipi` | `spi_pl_bronze_ipi` | `22813a5e-e833-4a82-a01d-98a4832cd325` |
| | `inv_bronze_energy` | `spi_pl_bronze_energy` | `8d8bd1f0-8f38-424e-812d-5192c1a59ccb` |
| | `inv_bronze_construction` | `spi_pl_bronze_construction` | `05e7facb-bd8a-4259-bf75-4bab33c43a1f` |
| | `inv_bronze_tax` | `spi_pl_bronze_tax` | `19e0bb0c-92a1-46f1-be3b-b5ac6ab6ed91` |
| `spi_pl_silver` | `inv_silver_ipc` | `spi_pl_silver_ipc` | `ea3f7f95-db37-4221-98e5-395bae4bad49` |
| | `inv_silver_ipi` | `spi_pl_silver_ipi` | `5ba95c71-7464-488b-bf2b-75a77e4027bd` |
| | `inv_silver_energy` | `spi_pl_silver_energy` | `68ba30e7-32a7-407e-9547-91ad9613fecc` |
| | `inv_silver_construction` | `spi_pl_silver_construction` | `29ba31a9-177a-4b17-83e6-e386e7804abd` |
| | `inv_silver_tax` | `spi_pl_silver_tax` | `91e631cf-fbeb-482f-a210-1faebc26622e` |
| `spi_pl_master` | `inv_bronze` | `spi_pl_bronze` | `a7804a03-1c1f-4b00-aae9-9979adf52ae1` |
| | `inv_silver` | `spi_pl_silver` | `035a2fa5-ea50-4441-8a4a-dad86ee77fac` |
| | `inv_gold` | `spi_pl_gold` | `55ef226b-d74c-4869-8be0-b048f4f941b7` |

`spi_pl_gold` invokes nothing (flat). `spi_pl_master` is created last:
its three IDs are the new `objectId`s of the layer pipelines.

- [ ] All thirteen

## 6. Notebooks' OneLake URIs

Workspace ID + Lakehouse ID (`c6048c3c-087e-4436-80fa-6013d1a04aeb`)
in the `abfss://` URL.

| Notebook | Constant |
|---|---|
| `spi_nb_bronze_energy` | target table URI (`…/Tables/spi_bronze_energy_raw`) |
| `spi_nb_bronze_construction` | target table URI (`…/Tables/spi_bronze_construction_raw`) |
| `spi_nb_bronze_tax` | target table URI (`…/Tables/spi_bronze_tax_raw`) |
| `spi_nb_silver_energy` | `TABLES_URI` |
| `spi_nb_silver_construction` | `TABLES_URI` |
| `spi_nb_silver_tax` | `TABLES_URI` |

`spi_nb_gold_refresh_sql_endpoint` resolves its IDs at runtime: no
change needed.

- [ ] All six

**Default-lakehouse metadata (all seven notebooks).** Since 2026-10-16
the repo notebooks are the Fabric exports, and their notebook metadata
(`metadata.dependencies.lakehouse`) binds `spi_lakehouse` by ID:
`default_lakehouse` and `known_lakehouses[].id` (Lakehouse ID),
`default_lakehouse_workspace_id` (workspace ID). No code reads it: the
notebooks write through the `abfss://` URLs above, and the Gold notebook
resolves the Lakehouse by name. After import, either re-attach
`spi_lakehouse` in the notebook's Lakehouse pane or replace the IDs
before import.

- [ ] All seven: default lakehouse re-attached or IDs replaced

---

## Found in the scan, beyond the list above

## 7. Pipeline `objectId`

Every pipeline JSON carries its own `objectId`, and Edit JSON code
rejects a paste whose `objectId` is not the new pipeline's own
(lessons-learned.md, Data Pipelines). Create each pipeline, then set
its `objectId` before pasting. The new `objectId`s of the per-source
and layer pipelines are also the new IDs for §5.

- [ ] All 14 (including `spi_pl_master`)

## 8. Bronze Copy activities: Lakehouse and source connections

| Pipeline | Field | Current value |
|---|---|---|
| `spi_pl_bronze_ipc` | Lakehouse sink `artifactId` | `c6048c3c-087e-4436-80fa-6013d1a04aeb` |
| `spi_pl_bronze_ipc` | INE HTTP source connection | `7c57fc1a-9505-493f-b37d-17cf6ccddb7a` |
| `spi_pl_bronze_ipi` | Lakehouse sink `artifactId` | `c6048c3c-087e-4436-80fa-6013d1a04aeb` |
| `spi_pl_bronze_ipi` | Azure SQL source connection (`spi_staging`) | `6b26a950-51d8-4b7e-8654-9d6d8897c34f` |

Connections are tenant objects, not workspace items. They may survive
the move and keep their IDs. Unverified.

**Azure SQL firewall.** `spi-sqlserver-gb` stays in North Europe
(ADR-019); the workspace moves to Sweden Central. If the server admits
Fabric through "Allow Azure services and resources to access this
server", nothing changes. If it admits Fabric by IP rules, the Copy
activity in `spi_pl_bronze_ipi` will be refused from the new region.
Checked before expiry (§0). Unverified.

- [ ] Lakehouse `artifactId` (both)
- [ ] Source connections, if recreated
- [ ] `spi_pl_bronze_ipi` reaches Azure SQL from Sweden Central

## 9. Dataflows' M (`03-src/dataflows/*.pq`)

The four IPC/IPI dataflows navigate to `spi_lakehouse` by ID:

```
Navigation = Source{[workspaceId = "bbffcd8e-…"]}[Data],
#"Navigation 1" = Navigation{[lakehouseId = "c6048c3c-…"]}[Data],
```

- [ ] `spi_df_silver_ipc`, `spi_df_silver_ipi`, `spi_df_gold_ipc`,
      `spi_df_gold_ipi`: both IDs

## 10. Dataflow data destinations

Not in the `.pq` exports: destinations are set in the dataflow UI. The
export header comments name them (Silver → `spi_lakehouse`, Gold and
dimensions → `spi_warehouse`). Per-query settings, update methods and
column mappings: `03-src/dataflows/destinations.md` (filled before
expiry, §0).

- [ ] Re-select the destination for all five dataflows, with the same
      update method (Silver: Replace; Gold facts: Append; check
      `spi_df_gold_dimensions`'s methods in Fabric before the move)

---

## No IDs

- `03-src/warehouse/*.sql`: names only. The procedure reads Silver by
  three-part name (`spi_lakehouse.dbo.<table>`), which holds as long as
  the Lakehouse keeps its name (see "Creating the items").

---

## Ideas for later

- **Notebooks resolve `TABLES_URI` at runtime**, as
  `spi_nb_gold_refresh_sql_endpoint` does with its IDs. That would
  remove §6 from the checklist. Not decided.

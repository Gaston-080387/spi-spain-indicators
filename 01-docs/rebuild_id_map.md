# Rebuild ID map — trial workspace → F2 workspace

Filled during the rebuild (started 2026-10-21). Each new ID replaces the old
one wherever `rebuild_checklist.md` lists it.

| Item | Old ID (trial, North Europe) | New ID (F2 `spifabricswc`, Sweden Central) |
|---|---|---|
| Workspace `spi-spain-indicators-dev` | `bbffcd8e-0f61-436d-bee8-eac2d26d38b2` | `49d06868-a854-4e7b-840b-3d66fba1d24a` |
| Lakehouse `spi_lakehouse` | `c6048c3c-087e-4436-80fa-6013d1a04aeb` | `9eab38c5-a0f9-48df-9f02-198c0ad250f6` (created without schemas; the dialog default is off) |
| Warehouse `spi_warehouse` | `bffbd9ed-33ad-4f34-a44a-18669a655853` | `798e8494-dd44-4996-8212-44adb3661863` |

The old workspace was renamed `spi-spain-indicators-dev-trial` to free the name.

| Endpoint | Old | New |
|---|---|---|
| Warehouse SQL endpoint | `s75vfahvn26u3ixeltcyscwbvy-r3g77o3bb5wuhpxi5lbne3jywi.datawarehouse.fabric.microsoft.com` | `s75vfahvn26u3ixeltcyscwbvy-nbunaskuvb5u5balhvtpxiosji.datawarehouse.fabric.microsoft.com` |

| Notebook | Old | New |
|---|---|---|
| `spi_nb_bronze_energy` | `f9650a1e-284a-4215-bf6b-165b80612e8b` | `8a94a9b7-dc34-4b62-9f1b-0458d6a5fb04` |
| `spi_nb_bronze_construction` | `8342eb88-69bc-4ec4-b606-5ae12c436649` | `eb8fae3e-1898-437c-81bd-479ae2c4a0cd` |
| `spi_nb_bronze_tax` | `6937abd8-f9e1-4419-a4ff-7dbebfd134b3` | `67eed4a5-0bf4-4ad9-86e5-0b706911a0ab` |

| Pipeline | Old | New |
|---|---|---|
| `spi_pl_bronze_ipc` | `9795a868-245d-4922-a301-add0c9a12981` | `1c9df234-7a15-42eb-8d54-8c1b3cfaa09c` |
| `spi_pl_bronze_ipi` | `22813a5e-e833-4a82-a01d-98a4832cd325` | `df853e41-5afc-4b39-b334-2f0d3009fffc` |
| `spi_pl_bronze_energy` | `8d8bd1f0-8f38-424e-812d-5192c1a59ccb` | `50532cb0-d863-4998-b8ec-267a984c2796` |
| `spi_pl_bronze_construction` | `05e7facb-bd8a-4259-bf75-4bab33c43a1f` | `32881517-9d69-4a62-a44b-a5bc6a177ff1` |
| `spi_pl_bronze_tax` | `19e0bb0c-92a1-46f1-be3b-b5ac6ab6ed91` | `bd9e5109-7ad8-4201-a375-565cd43d6b7b` |
| `spi_pl_bronze` | `a7804a03-1c1f-4b00-aae9-9979adf52ae1` | `c85550c0-8ada-4bf9-bfc0-69722dfca59d` |

| Silver layer item | Old | New |
|---|---|---|
| `spi_df_silver_ipc` | `fcf4c859-c17b-463f-a14e-bec307749f23` | `d4d9f393-1d0f-4f63-997d-5196de1b4f70` |
| `spi_df_silver_ipi` | `46ea17b3-645b-4ad2-9c5e-85ca517f4522` | `a1491edf-1d7d-4e30-8786-e7ffeb24e708` |
| `spi_nb_silver_energy` | `961c215d-868e-4c15-85c6-e2a33161b54c` | `e3e0295c-bc10-492f-8d8c-241162a950bf` |
| `spi_nb_silver_construction` | `5cc35d40-ff8a-4f25-971f-78ac8e1d59ea` | `c9f86b5a-b88f-4101-8dbf-df93c9700f3a` |
| `spi_nb_silver_tax` | `58d57fc9-0237-4143-9e63-5e65256e10ec` | `a040bdb2-a1df-4541-8f6f-26fae8fc0f7f` |
| `spi_pl_silver_ipc` | `ea3f7f95-db37-4221-98e5-395bae4bad49` | `7129cdac-aed0-4eb4-8185-51101830c8d6` |
| `spi_pl_silver_ipi` | `5ba95c71-7464-488b-bf2b-75a77e4027bd` | `f70594b0-e438-4fac-b8a9-bb5982b4d0cd` |
| `spi_pl_silver_energy` | `68ba30e7-32a7-407e-9547-91ad9613fecc` | `27b51069-a0ff-4f59-b630-59d789aaa482` |
| `spi_pl_silver_construction` | `29ba31a9-177a-4b17-83e6-e386e7804abd` | `bb329e7b-725b-4759-9787-8dfed4714a23` |
| `spi_pl_silver_tax` | `91e631cf-fbeb-482f-a210-1faebc26622e` | `f2e75838-69aa-4496-b792-61a9b19cb81f` |
| `spi_pl_silver` | `035a2fa5-ea50-4441-8a4a-dad86ee77fac` | `2c2d3629-38ac-4d92-9682-2c05b92babc4` |

| Gold layer item | Old | New |
|---|---|---|
| `spi_df_gold_ipc` | `6cb21ab8-9fb9-427b-bcb0-62a7e66cdbc3` | `9be686c7-dd0e-4f07-8f1a-4e3c5643de77` |
| `spi_df_gold_ipi` | `5ec5cbee-80a6-45d2-aa7d-c2e51124cc53` | `24d959d7-3953-4a21-bd5e-683cf081d47f` |
| `spi_nb_gold_refresh_sql_endpoint` | `db02c520-4b6f-4c6c-a654-ab60e499fa5b` | `e2fe7a3a-cb77-47da-80f5-9b602db8b743` |
| `spi_pl_gold` | `55ef226b-d74c-4869-8be0-b048f4f941b7` | `df904a56-c52c-4fa8-8c94-896a38d28c8f` |
| `spi_pl_master` | `abda9a40-ee06-4a8c-a986-59fadce1236f` | `9b0007a4-cfc1-4f03-9a54-c762a12dc352` |

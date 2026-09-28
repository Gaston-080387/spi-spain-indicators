// Dataflow:    spi_df_gold_dimensions
// Layer:       Gold
// Destination: spi_warehouse — spi_dim_region, spi_dim_calendar,
//              spi_dim_indicator  (Replace)
// Purpose:     Seeded dimensions. Keys are assigned explicitly and must
//              never be reused or renumbered (ADR-010). spi_dim_indicator
//              keys come from one sequence across all sources.

/* spi_dim_region */
let
  Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("i45WMlTSUfJzdAaRicmZ+XmJOUCmY3p6UWp6YklqioJfYglENFYnWskIKOfsGAIiE0sSc0oPb0wEqS4tyc/Lz80vLVZwzs/NLc3LLKkEKzcGSvo6uoDIxJSizBScamMB", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type nullable text) meta [Serialized.Text = true]) in type table [region_key = _t, region_code = _t, region_name = _t, region_type = _t]),
  #"Changed column type" = Table.TransformColumnTypes(Source, {{"region_key", Int64.Type}, {"region_code", type text}, {"region_name", type text}, {"region_type", type text}})
in
  #"Changed column type"

/* spi_dim_calendar */
let
    StartYear   = 2000,
    EndYear     = Date.Year(DateTime.LocalNow()),
    CurrentYear = EndYear,

    // One row per month: 2000-01 through December of the current year
    MonthStarts = List.Generate(
        () => #date(StartYear, 1, 1),
        each _ <= #date(EndYear, 12, 1),
        each Date.AddMonths(_, 1)
    ),
    Source = Table.FromList(MonthStarts, Splitter.SplitByNothing(), {"month_start"}),

    AddYear    = Table.AddColumn(Source,    "year",  each Date.Year([month_start]),  Int64.Type),
    AddMonth   = Table.AddColumn(AddYear,   "month", each Date.Month([month_start]), Int64.Type),
    AddKey     = Table.AddColumn(AddMonth,  "calendar_key", each [year] * 100 + [month], Int64.Type),
    AddName    = Table.AddColumn(AddKey,    "month_name",
                    each Date.MonthName([month_start], "en-US"), type text),
    AddQuarter = Table.AddColumn(AddName,   "quarter",
                    each Date.QuarterOfYear([month_start]), Int64.Type),
    AddYM      = Table.AddColumn(AddQuarter, "year_month",
                    each Text.From([year]) & "-" & Text.PadStart(Text.From([month]), 2, "0"), type text),
    AddCurrent = Table.AddColumn(AddYM,     "is_current_year",
                    each [year] = CurrentYear, type logical),

    Result = Table.SelectColumns(AddCurrent,
        {"calendar_key", "year", "month", "month_name", "quarter", "year_month", "is_current_year"})
in
    Result

/* spi_dim_indicator */
let
  Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("tVVLbtswEL0K4bULSHL8ybIxsvAiQNAE3RhZjMiJzIIiXZIymtyhR8miyBF0sQ7l1pI/jUO13RjkePjem+HjaLkcpIPhYHE7Zx8Y+6hkidobx55YjrkU4Jg2DBQ3q/pVSQ6OkpP0nYlzo11VomW3VnIMkYUW+I3l4JBlSTamyI3RfqWeBg/D5SBrlVz9Au0iEpeHHLgJGrKzKbHso5b9MzovhSE0DuoZRMM4OhmOZbnosMiNRC1gyKCo6BcVck8oVJUYsqKpxnhLTeamzCvizlXDkFz0Pxurd9zqvakwgBCl9fULrxShC1RsZQqwxNcJr8ECaWIlaI9aljKYhaRYG1bYHgvVjP8Xcmytk7bWO9ChlUHepLOJRZy2iPcWtFsb6zGATvf3sbizFnehH40tgcv6VQdnmrLS9BS4NHprltnZlFj2y87E4J6cSM1Bxyxyi0B7oJsU2NQW6CrlKwtBymVcfqyuNGmFXWuH9Q/QzwEoTfb30cCdGfmJhgCQPjJbeGQO7YaeXWNYGkXmC2wtGVjTiORoSZ1heYdFZc0+waPUoLlEigcp2TuSoiV0Jua8Cpdq2BqtMxrUkK2t8ci3nnOGyxCjjwXVe9gKuQmHGpmjfwQUXUo7luvvWtAZVhC+BUXx40g0/HaKLgj+3nhQTGpBM9nKYMbjyOL3WhGBERW9GaOPSNJDksmO5GrbHDIZb5Sa8HEW5ENBV01Z5/7vKWD6ZwGnSPsTzU4Q4ddKrvd5dqGeNJdvNPTNbv51K7NkR31Npivql+CLzrInbHpYkaTJZEsUsnk2J4M9qB5+Ag==", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type nullable text) meta [Serialized.Text = true]) in type table [indicator_key = _t, indicator_name = _t, indicator_category = _t, domain = _t, unit_of_measure = _t, frequency = _t]),
  #"Changed column type" = Table.TransformColumnTypes(Source, {{"indicator_key", Int64.Type}, {"indicator_name", type text}, {"indicator_category", type text}, {"domain", type text}, {"unit_of_measure", type text}, {"frequency", type text}})
in
  #"Changed column type"
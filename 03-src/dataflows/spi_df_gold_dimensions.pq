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
  Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("tVZLbtswEL0K4bUb+JP4s0wcF9AiaGC76SLIgiYnMguJdCnKSHKHHqSLLIocQRfrjJRYsq3EpttuDGk8fO/NaPjI29tGu9FsBNcj9omx80jFoJ1J2CObw1xJnjBtGI+EWWQvkRI8weRW+8DEkdFJGoNl11YJoEigJTywOU+AdVqdM4xcGe0W0WPjrnnb6JRKLl5Bq4jI5ficC0MaOntTfNm7JfsNJE5Jg2iCR09c5ozd2rAvy2mFRa0UaMmbjIcp/kIEwiEKViWbLMyrMc5ik4WJ5ylyz6OcoXV6/FpfvWel3qsUCAQprcueRRohuoSILUzILfJVwktuOWpiMdcOtIoVDQtKsZaeoFxG1Zz9L2TfWntlrVOuqZUkr1d58UXsl4gzy3WyNNYBgfY3331xByVuoO+NjblQ2YumyTRxqnErCGV0MSyDvSm+7MOKYwiHk4jNgYRZEBY4vnP8khLy2ogujVxqOUkZ+uX76mq3SmFjnUD2m+snAmq3Nt+9gSseOUET4KgPh402WQJ2hdsuH1i0IvOdFyNJrG2PZG9JFbOcQphas0lwrzTXQgHGSUrngCRvCRXHHKX0UQ1bgk2M5lGTLa1xIIqZS4xQFMPDAuvdboVa0aJcZvcfAXmXUtpy9lNLXMNCxLc8wvhuxBu+cNEA4WfG8YgpLdGTraJh3I0Eb88REhiZ4p4xeoekvU3SW5NcFM3BIRO5UkOHs8Q5lPipMWvf/0cK6L8voI70eKJBDRH8SNVyk2cdOpJm+EFDP+zmX7ey01pTj3HowuyZ5qLyeCRse7sihc5kY5Aq3za1wSOpOm+CH5HtEvC8lnRwZ7/yewrVUBsslhDYt8U2ZPd16zlbiFhvJ/EaLEwCe4aum9/TctMjQ2HT3DnW281nRZWSABYmTVA4G3+dbCs8PVhhfiLMAK8tzlBvcxfxyfVQRe4z4w8IFUyuP+N1ILSAPsk0uOIL10ZpxQRWoFPYg98r8W/Oa+Drgoej90v0k+mXUTC+PL8cT2toPvz3cL5ByRecjMcnNUzvxA/nGK456IZgdqHeCR/GcPcH", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type nullable text) meta [Serialized.Text = true]) in type table [indicator_key = _t, indicator_name = _t, indicator_category = _t, domain = _t, unit_of_measure = _t, frequency = _t]),
  #"Changed column type" = Table.TransformColumnTypes(Source, {{"indicator_key", Int64.Type}, {"indicator_name", type text}, {"indicator_category", type text}, {"domain", type text}, {"unit_of_measure", type text}, {"frequency", type text}})
in
  #"Changed column type"
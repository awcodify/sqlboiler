{{- $tableNameSingular := .Table.Name | singular | titleCase -}}
{{- $varNameSingular := .Table.Name | singular | camelCase -}}
{{- $colDefs := sqlColDefinitions .Table.Columns .Table.PKey.Columns -}}
{{- $pkNames := $colDefs.Names | stringMap .StringFuncs.camelCase -}}
{{- $pkArgs := joinSlices " " $pkNames $colDefs.Types | join ", "}}
// UpdateG a single {{$tableNameSingular}} record. See Update for
// whitelist behavior description.
func (o *{{$tableNameSingular}}) UpdateG(whitelist ...string) error {
  return o.Update(boil.GetDB(), whitelist...)
}

// UpdateGP a single {{$tableNameSingular}} record.
// UpdateGP takes a whitelist of column names that should be updated.
// Panics on error. See Update for whitelist behavior description.
func (o *{{$tableNameSingular}}) UpdateGP(whitelist ...string) {
  if err := o.Update(boil.GetDB(), whitelist...); err != nil {
    panic(boil.WrapErr(err))
  }
}

// UpdateP uses an executor to update the {{$tableNameSingular}}, and panics on error.
// See Update for whitelist behavior description.
func (o *{{$tableNameSingular}}) UpdateP(exec boil.Executor, whitelist ... string) {
  err := o.Update(exec, whitelist...)
  if err != nil {
    panic(boil.WrapErr(err))
  }
}

// Update uses an executor to update the {{$tableNameSingular}}.
// Whitelist behavior: If a whitelist is provided, only the columns given are updated.
// No whitelist behavior: Without a whitelist, columns are inferred by the following rules:
// - All columns are inferred to start with
// - All primary keys are subtracted from this set
func (o *{{$tableNameSingular}}) Update(exec boil.Executor, whitelist ... string) error {
  if err := o.doBeforeUpdateHooks(); err != nil {
    return err
  }

  var err error
  var query string
  var values []interface{}

  wl := o.generateUpdateColumns(whitelist...)

  if len(wl) != 0 {
    query = fmt.Sprintf(`UPDATE {{.Table.Name}} SET %s WHERE %s`, strmangle.SetParamNames(wl), strmangle.WhereClause(len(wl)+1, {{$varNameSingular}}PrimaryKeyColumns))
    values = boil.GetStructValues(o, wl...)
    values = append(values, {{.Table.PKey.Columns | stringMap .StringFuncs.titleCase | prefixStringSlice "o." | join ", "}})

    if boil.DebugMode {
      fmt.Fprintln(boil.DebugWriter, query)
      fmt.Fprintln(boil.DebugWriter, values)
    }

    _, err = exec.Exec(query, values...)
  } else {
    return fmt.Errorf("{{.PkgName}}: unable to update {{.Table.Name}}, could not build whitelist")
  }

  if err != nil {
    return fmt.Errorf("{{.PkgName}}: unable to update {{.Table.Name}} row: %s", err)
  }

  if err := o.doAfterUpdateHooks(); err != nil {
    return err
  }

  return nil
}

// UpdateAllP updates all rows with matching column names, and panics on error.
func (q {{$varNameSingular}}Query) UpdateAllP(cols M) {
  if err := q.UpdateAll(cols); err != nil {
    panic(boil.WrapErr(err))
  }
}

// UpdateAll updates all rows with the specified column values.
func (q {{$varNameSingular}}Query) UpdateAll(cols M) error {
  boil.SetUpdate(q.Query, cols)

  _, err := boil.ExecQuery(q.Query)
  if err != nil {
    return fmt.Errorf("{{.PkgName}}: unable to update all for {{.Table.Name}}: %s", err)
  }

  return nil
}

// UpdateAllG updates all rows with the specified column values.
func (o {{$tableNameSingular}}Slice) UpdateAllG(cols M) error {
  return o.UpdateAll(boil.GetDB(), cols)
}

// UpdateAllGP updates all rows with the specified column values, and panics on error.
func (o {{$tableNameSingular}}Slice) UpdateAllGP(cols M) {
  if err := o.UpdateAll(boil.GetDB(), cols); err != nil {
    panic(boil.WrapErr(err))
  }
}

// UpdateAllP updates all rows with the specified column values, and panics on error.
func (o {{$tableNameSingular}}Slice) UpdateAllP(exec boil.Executor, cols M) {
  if err := o.UpdateAll(exec, cols); err != nil {
    panic(boil.WrapErr(err))
  }
}

// UpdateAll updates all rows with the specified column values, using an executor.
func (o {{$tableNameSingular}}Slice) UpdateAll(exec boil.Executor, cols M) error {
  if o == nil {
    return errors.New("{{.PkgName}}: no {{$tableNameSingular}} slice provided for update all")
  }

  if len(o) == 0 {
    return nil
  }

  colNames := make([]string, len(cols))
  var args []interface{}

  count := 0
  for name, value := range cols {
    colNames[count] = strmangle.IdentQuote(name)
    args = append(args, value)
    count++
  }

  // Append all of the primary key values for each column
  args = append(args, o.inPrimaryKeyArgs()...)

  sql := fmt.Sprintf(
    `UPDATE {{.Table.Name}} SET (%s) = (%s) WHERE (%s) IN (%s)`,
    strings.Join(colNames, ", "),
    strmangle.Placeholders(len(colNames), 1, 1),
    strings.Join(strmangle.IdentQuoteSlice({{$varNameSingular}}PrimaryKeyColumns), ","),
    strmangle.Placeholders(len(o) * len({{$varNameSingular}}PrimaryKeyColumns), len(colNames)+1, len({{$varNameSingular}}PrimaryKeyColumns)),
  )

  if boil.DebugMode {
    fmt.Fprintln(boil.DebugWriter, sql)
    fmt.Fprintln(boil.DebugWriter, args...)
  }

  _, err := exec.Exec(sql, args...)
  if err != nil {
    return fmt.Errorf("{{.PkgName}}: unable to update all in {{$varNameSingular}} slice: %s", err)
  }

  return nil
}

// generateUpdateColumns generates the whitelist columns for an update statement
// if a whitelist is supplied, it's returned
// if a whitelist is missing then we begin with all columns
// then we remove the primary key columns
func (o *{{$tableNameSingular}}) generateUpdateColumns(whitelist ...string) []string {
  if len(whitelist) != 0 {
    return whitelist
  }

  return boil.SetComplement({{$varNameSingular}}Columns, {{$varNameSingular}}PrimaryKeyColumns)
}

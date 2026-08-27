($patch[0]) as $p
| del(.rotation_strategy, .retention_strategy)
| .rotation_strategy = (
    $p.rotation_strategy
    | del(
        .index_lifetime_min,
        .index_lifetime_max,
        .rotation_period,
        .rotate_empty_index_set,
        .max_rotation_period
      )
  )
| .retention_strategy = $p.retention_strategy
| .rotation_strategy_class = $p.rotation_strategy_class
| .retention_strategy_class = $p.retention_strategy_class
| .use_legacy_rotation = $p.use_legacy_rotation
| .data_tiering = $p.data_tiering

WITH aggregated_statcast AS (
    SELECT pitcher, game_year, 
          MAX(release_speed) AS velo_max, 
          MIN(release_speed) AS velo_min, 
          ROUND(CAST((MAX(release_speed) - MIN(release_speed)) AS NUMERIC), 1) AS velo_range,
		    ROUND(CAST((PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY release_speed) - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY release_speed)) AS NUMERIC), 1) AS velo_iqr,
		    MAX(pfx_z) AS vertical_movement_max,
		    ROUND(CAST((MAX(pfx_z) - MIN(pfx_z)) AS NUMERIC), 1) AS vertical_movement_range,
		    ROUND(CAST((PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY pfx_z) - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY pfx_z)) AS NUMERIC), 1) AS vertical_movement_iqr,
		    MAX(pfx_x) AS horizontal_movement_max,
		    ROUND(CAST((MAX(pfx_x) - MIN(pfx_x)) AS NUMERIC), 1) AS horizontal_movement_range,
		    ROUND(CAST((PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY pfx_x) - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY pfx_x)) AS NUMERIC), 1) AS horizontal_movement_iqr,
		    MAX(release_pos_z) AS vertical_release_max,
		    ROUND(CAST((MAX(release_pos_z) - MIN(release_pos_z)) AS NUMERIC), 1) AS vertical_release_range,
		    ROUND(CAST((PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY release_pos_z) - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY release_pos_z)) AS NUMERIC), 1) AS vertical_release_iqr,
		    MAX(release_pos_x) AS horizontal_release_max,
		    ROUND(CAST((MAX(release_pos_x) - MIN(release_pos_x)) AS NUMERIC), 1) AS horizontal_release_range,
		    ROUND(CAST((PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY release_pos_x) - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY release_pos_x)) AS NUMERIC), 1) AS horizontal_release_iqr,
		    MAX(release_spin_rate) AS release_spin_rate_max,
		    MIN(release_spin_rate) AS release_spin_rate_min,
		    ROUND(CAST((MAX(release_spin_rate) - MIN(release_spin_rate)) AS NUMERIC), 1) AS release_spin_rate_range,
		    ROUND(CAST((PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY release_spin_rate) - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY release_spin_rate)) AS NUMERIC), 1) AS release_spin_rate_iqr
    FROM statcast
    WHERE game_date NOT BETWEEN '2021-03-01' AND '2021-03-31'
   	   AND game_date NOT BETWEEN '2015-03-28' AND '2015-04-04'
   	   AND game_date NOT BETWEEN '2016-03-28' AND '2016-04-02'
   	   AND game_date NOT BETWEEN '2017-03-28' AND '2017-04-01'
    GROUP BY pitcher, game_year
    ORDER BY pitcher, game_year
)
SELECT * FROM aggregated_statcast;
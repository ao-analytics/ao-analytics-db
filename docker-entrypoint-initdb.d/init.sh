pgdata=/var/lib/postgresql/data
pgconf=${pgdata}/postgresql.conf

echo "shared_preload_libraries = 'pg_partman_bgw, pg_cron'" >> ${pgconf}
echo "cron.database_name = 'ao'" >> ${pgconf}

pg_ctl -D ${pgdata} restart -m fast
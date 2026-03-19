#!/bin/bash
# ─────────────────────────────────────────────────────────────
# init-replication.sh
# Wires MySQL primary → replica1 + replica2 via GTID replication
# ─────────────────────────────────────────────────────────────
set -e  # exit immediately if any command fails

# ─── VARIABLES ───────────────────────────────────────────────
ROOT_PASS="RootPass123!"
REPL_USER="replicator"
REPL_PASS="ReplPass123!"
MONITOR_USER="monitor"
MONITOR_PASS="MonitorPass123!"
PRIMARY="mysql-primary"
REPLICAS=("mysql-replica1" "mysql-replica2")
MAX_WAIT=120   # max seconds to wait for a node to be ready

# ─── HELPER: wait for a MySQL node to be ready ───────────────
wait_for_mysql() {
  local HOST=$1
  local ELAPSED=0
  echo "⏳ Waiting for $HOST to be ready..."
  until docker exec $HOST mysqladmin ping \
        -uroot -p$ROOT_PASS --silent 2>/dev/null; do
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    if [ $ELAPSED -ge $MAX_WAIT ]; then
      echo "❌ ERROR: $HOST did not become ready in ${MAX_WAIT}s"
      exit 1
    fi
    echo "   ... still waiting for $HOST ($ELAPSED s)"
  done
  echo "✅ $HOST is ready!"
}

# ─── HELPER: check replication status on a replica ───────────
check_replication() {
  local REPLICA=$1
  echo ""
  echo "📊 Replication status on $REPLICA:"
  docker exec $REPLICA mysql -uroot -p$ROOT_PASS \
    -e "SHOW SLAVE STATUS\G" 2>/dev/null \
    | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Master_Host"
}

# ─────────────────────────────────────────────────────────────
# PHASE 1 — Wait for all nodes
# ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo " PHASE 1: Waiting for all nodes"
echo "════════════════════════════════════════"

wait_for_mysql $PRIMARY
for REPLICA in "${REPLICAS[@]}"; do
  wait_for_mysql $REPLICA
done

# ─────────────────────────────────────────────────────────────
# PHASE 2 — Create replication user on primary
# ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo " PHASE 2: Creating replication user"
echo "════════════════════════════════════════"

docker exec $PRIMARY mysql -uroot -p$ROOT_PASS <<EOF
-- Replication user (used by replicas to connect to primary)
CREATE USER IF NOT EXISTS '$REPL_USER'@'%'
  IDENTIFIED WITH mysql_native_password BY '$REPL_PASS';
GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'%';

-- Monitor user (used by ProxySQL to health-check all nodes)
CREATE USER IF NOT EXISTS '$MONITOR_USER'@'%'
  IDENTIFIED WITH mysql_native_password BY '$MONITOR_PASS';
GRANT SELECT, REPLICATION CLIENT ON *.* TO '$MONITOR_USER'@'%';

FLUSH PRIVILEGES;

SELECT 'Replication user created successfully' AS status;
EOF

echo "✅ Replication and monitor users created on primary"

# ─────────────────────────────────────────────────────────────
# PHASE 3 — Configure each replica
# ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo " PHASE 3: Configuring replicas"
echo "════════════════════════════════════════"

for REPLICA in "${REPLICAS[@]}"; do
  echo ""
  echo "🔗 Configuring $REPLICA..."

  docker exec $REPLICA mysql -uroot -p$ROOT_PASS <<EOF
-- Stop any existing replication
STOP SLAVE;
RESET SLAVE ALL;

-- Point replica to primary using GTID auto-positioning
CHANGE MASTER TO
  MASTER_HOST='$PRIMARY',
  MASTER_PORT=3306,
  MASTER_USER='$REPL_USER',
  MASTER_PASSWORD='$REPL_PASS',
  MASTER_AUTO_POSITION=1;

-- Start replication
START SLAVE;

SELECT 'Replication started on $REPLICA' AS status;
EOF

  # give it 3 seconds to connect
  sleep 3

  # verify
  check_replication $REPLICA
done

# ─────────────────────────────────────────────────────────────
# PHASE 4 — Final validation
# ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo " PHASE 4: Final validation"
echo "════════════════════════════════════════"

# Write a test record on primary
docker exec $PRIMARY mysql -uroot -p$ROOT_PASS testdb <<EOF
CREATE TABLE IF NOT EXISTS replication_test (
  id INT AUTO_INCREMENT PRIMARY KEY,
  message VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO replication_test (message)
  VALUES ('Replication init test - $(date)');
EOF

echo "✅ Test record written to primary"

# Wait for replication to catch up
sleep 3

# Verify record exists on both replicas
for REPLICA in "${REPLICAS[@]}"; do
  COUNT=$(docker exec $REPLICA mysql -uroot -p$ROOT_PASS testdb \
    -se "SELECT COUNT(*) FROM replication_test;" 2>/dev/null)
  if [ "$COUNT" -ge "1" ]; then
    echo "✅ $REPLICA received the test record (count: $COUNT)"
  else
    echo "❌ ERROR: $REPLICA did NOT receive the test record!"
    exit 1
  fi
done

echo ""
echo "════════════════════════════════════════"
echo " ✅ REPLICATION FULLY INITIALIZED"
echo " Primary  → mysql-primary"
echo " Replica1 → mysql-replica1"
echo " Replica2 → mysql-replica2"
echo " Mode     → GTID Auto-Position"
echo "════════════════════════════════════════"
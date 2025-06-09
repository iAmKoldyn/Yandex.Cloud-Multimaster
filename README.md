# Yandex.Cloud MultiMaster MySQL Setup

This repository provides instructions for creating a multi-master MySQL cluster in Yandex Cloud. The setup uses two **Windows Server** virtual machines. Each VM runs MySQL configured with Group Replication so that both nodes can accept writes.

## Prerequisites

- Yandex Cloud account with sufficient quota to create two Windows Server instances
- [Yandex Cloud CLI](https://cloud.yandex.com/en/docs/cli/quickstart) (`yc`) installed and configured
- Access to install MySQL on Windows (for example via the [MySQL Installer for Windows](https://dev.mysql.com/downloads/installer/))

## Connecting with the Yandex Cloud CLI

Configure the CLI for your cloud and folder (replace with your IDs if different):

```bash
yc config set cloud-id cloud-nphne-2xsw2s3a
yc config set folder-id b1ge8i9vtd79bg2dkvu5
yc init
```

## Creating the VMs

1. Create two VM instances using `yc compute instance create`. Example:

```bash
yc compute instance create \
  --name mysql-node1 \
  --zone ru-central1-a \
  --network-interface subnet-name=<your-subnet>,nat-ip-version=ipv4 \
  --platform standard-v1 \
  --cores 4 --memory 8G \
  --create-boot-disk type=network-hdd,size=64GB,image-family=windows-2022-gv2 \
  --ssh-key ~/.ssh/id_rsa.pub  # used to retrieve the initial Administrator password
```

Retrieve the password with:

```bash
yc compute instance get-serial-port-output mysql-node1 | grep password
```

Create a second VM `mysql-node2` in the same way (possibly in a different zone). Both machines should run Windows Server.

## Installing MySQL and Configuring Group Replication

1. Log in to each VM via RDP and install MySQL 8.x using the MySQL Installer for Windows.
2. Enable the Group Replication plugin. In `/etc/mysql/mysql.conf.d/mysqld.cnf`, add:

```ini
[mysqld]
server-id=1        # change to 2 on the second node
log_bin=mysql-bin
binlog_format=ROW
transaction_write_set_extraction=XXHASH64
default_authentication_plugin=mysql_native_password
plugin-load-add=group_replication.so
group_replication_group_name="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
group_replication_start_on_boot=off
group_replication_local_address="<node_ip>:33061"
group_replication_group_seeds="<node1_ip>:33061,<node2_ip>:33061"
```

3. On the first node initialize the group:

```sql
CREATE USER 'repl'@'%' IDENTIFIED BY 'replica';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='replica' FOR CHANNEL 'group_replication_recovery';
START GROUP_REPLICATION;
```

4. On the second node run the same but add `server-id=2` and then join:

```sql
CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='replica' FOR CHANNEL 'group_replication_recovery';
START GROUP_REPLICATION;
```

When `SHOW STATUS LIKE 'group_replication_primary_member';` returns a UUID from either node, the cluster is operational.

## Application Connection Logic

- The application (A-Server) should attempt to connect to `mysql-node1` first.
- If the connection fails, the application connects to `mysql-node2`.
- Clients access the application through the first host. If it becomes unavailable, clients are directed to the second host.

This simple active/standby scheme can be implemented using a load balancer or application logic.

An example PowerShell helper script is provided in `scripts/connect.ps1` that attempts to connect to the primary node and falls back to the secondary node if needed.

## Failover Notes

If one database host fails, Group Replication elects the surviving node as primary so it continues to accept writes. When the failed node is restored, it rejoins the group automatically.


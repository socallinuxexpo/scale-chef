# Standard Operating Procedures (SOPs)

## Table of Contents

* [Decomissioning an EC2 Instance](#decomissioning-an-ec2-instance)
* [Decomissioning an RDS Database](#decomissioning-an-rds-database)
* [Decomissioning a non-RDS (local) Database](#decomissioning-a-non-rds-local-database)

## Decomissioning an EC2 Instance

* Stop the instance
   * Choose the instance, and then `Actions` -> `Instance State` -> `Stop`
   * Wait for the instance to stop
* In most case, it makes sense to wait one week to ensure it wasn't unexpectedly needed.
* Terminate the instance
   * Choose the instance, and then `Actions` -> `Instance State` -> `Terminate`
   * Wait for the instance to terminate

## Decomissioning an RDS Database

* Take a Snapshot of the database
   * Choose the "Regional Cluster" and then `Actions` -> `Take Snapshot`
   * Name the snapshot something like "<name-of-db>-decomission-<YYYY>-<MM>-<DD>",
      i.e. "scale-drupal-decomission-2024-06-01"
* Wait for the snapshot to complete
* Delete the database instance
   * Delete protection is probably on ("delete" is grayed out in the `Actions` menu), so you must modify the cluster and disable delete protection
   * Then choose the cluster, and Action -> Delete
      * For some DB types, you may have to start at the bottom and delete instances before you can delete the cluster.
   * When it asks if you want to take a final snapshot, choose "no" (you took one above, right?)

### Decomissioning a non-RDS (local) Database

We don't have any of these at the moment, but if we ever do then the correct
process would be to do a dump (mysqldump or similar), gzip it, and put it into
S3.

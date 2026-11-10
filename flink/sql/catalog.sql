CREATE CATALOG iceberg_demo WITH (
  'type' = 'iceberg',
  'catalog-type' = 'rest',
  'uri' = 'http://seaweedfs:8181',
  'warehouse' = 's3://entertainment-iceberg',
  'rest.auth.type' = 'sigv4',
  'rest.signing-name' = 's3',
  'rest.signing-region' = 'us-east-1',
  'io-impl' = 'org.apache.iceberg.aws.s3.S3FileIO',
  's3.endpoint' = 'http://seaweedfs:8333',
  's3.path-style-access' = 'true'
);
SET 'table.local-time-zone' = 'UTC';
USE CATALOG iceberg_demo;

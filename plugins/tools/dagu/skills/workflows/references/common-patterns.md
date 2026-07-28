# Dagu Common Patterns Reference

Complete workflow artifacts for four recurring shapes: ETL pipeline, multi-environment
deployment, database backup, and health-check monitoring. Adapt names, hosts, and
commands to the target system before use.

## Contents

- [ETL Pipeline](#etl-pipeline)
- [Multi-Environment Deployment](#multi-environment-deployment)
- [Data Backup Workflow](#data-backup-workflow)
- [Monitoring and Alerts](#monitoring-and-alerts)

### ETL Pipeline

```yaml
name: etl_pipeline
description: Extract, Transform, Load data pipeline

schedule: "0 2 * * *"  # Daily at 2 AM

env:
  - DATA_SOURCE: s3://bucket/data
  - TARGET_DB: postgresql://localhost/warehouse

steps:
  - name: extract
    command: ./extract.sh $DATA_SOURCE
    output: EXTRACTED_FILE

  - name: transform
    depends:
      - extract
    command: ./transform.sh $EXTRACTED_FILE
    output: TRANSFORMED_FILE

  - name: load
    depends:
      - transform
    command: ./load.sh $TRANSFORMED_FILE $TARGET_DB

  - name: cleanup
    depends:
      - load
    command: rm -f $EXTRACTED_FILE $TRANSFORMED_FILE

handlerOn:
  failure:
    - name: alert
      executor:
        type: mail
        config:
          to: data-team@example.com
          subject: "ETL Pipeline Failed"
```

### Multi-Environment Deployment

```yaml
name: deploy
description: Deploy application to multiple environments

params: ENVIRONMENT=staging VERSION=latest

steps:
  - name: build
    command: docker build -t app:$VERSION .

  - name: test
    depends:
      - build
    command: docker run app:$VERSION npm test

  - name: deploy_staging
    depends:
      - test
    preconditions:
      - condition: "`echo $ENVIRONMENT`"
        expected: "staging"
    executor:
      type: ssh
      config:
        user: deploy
        host: staging.example.com
    command: ./deploy.sh $VERSION

  - name: deploy_production
    depends:
      - test
    preconditions:
      - condition: "`echo $ENVIRONMENT`"
        expected: "production"
    executor:
      type: ssh
      config:
        user: deploy
        host: prod.example.com
    command: ./deploy.sh $VERSION
```

### Data Backup Workflow

```yaml
name: database_backup
description: Automated database backup workflow

schedule: "0 3 * * *"  # Daily at 3 AM

env:
  - DB_HOST: localhost
  - DB_NAME: myapp
  - BACKUP_DIR: /backups
  - S3_BUCKET: s3://backups/db

steps:
  - name: create_backup
    command: |
      TIMESTAMP=$(date +%Y%m%d_%H%M%S)
      pg_dump -h $DB_HOST $DB_NAME > $BACKUP_DIR/backup_$TIMESTAMP.sql
      echo "backup_$TIMESTAMP.sql"
    output: BACKUP_FILE

  - name: compress
    depends:
      - create_backup
    command: gzip $BACKUP_DIR/$BACKUP_FILE
    output: COMPRESSED_FILE

  - name: upload_to_s3
    depends:
      - compress
    command: aws s3 cp $BACKUP_DIR/$COMPRESSED_FILE.gz $S3_BUCKET/

  - name: cleanup_old_backups
    depends:
      - upload_to_s3
    command: |
      find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete
      aws s3 ls $S3_BUCKET/ | awk '{print $4}' | head -n -30 | xargs -I {} aws s3 rm $S3_BUCKET/{}

handlerOn:
  failure:
    - name: alert_failure
      executor:
        type: mail
        config:
          to: dba@example.com
          subject: "Backup Failed"
  success:
    - name: log_success
      command: echo "Backup completed at $(date)" >> /var/log/backups.log
```

### Monitoring and Alerts

```yaml
name: health_check
description: Monitor services and send alerts

schedule: "*/5 * * * *"  # Every 5 minutes

steps:
  - name: check_web_service
    command: curl -f https://app.example.com/health
    retryPolicy:
      limit: 3
      intervalSec: 10
    continueOn:
      failure: true

  - name: check_api_service
    command: curl -f https://api.example.com/health
    retryPolicy:
      limit: 3
      intervalSec: 10
    continueOn:
      failure: true

  - name: check_database
    command: pg_isready -h db.example.com
    continueOn:
      failure: true

handlerOn:
  failure:
    - name: alert_on_failure
      executor:
        type: http
        config:
          method: POST
          url: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
          headers:
            Content-Type: application/json
          body: |
            {
              "text": "⚠️ Service health check failed",
              "attachments": [{
                "color": "danger",
                "fields": [
                  {"title": "Workflow", "value": "{{.Name}}", "short": true},
                  {"title": "Time", "value": "{{.timestamp}}", "short": true}
                ]
              }]
            }
```


"""
HMA Infrastructure Evidence Collectors

Periodic Huey tasks that collect evidence from HMA infrastructure
and store it in MinIO for compliance auditing.
"""

import json
import hashlib
import logging
from datetime import datetime
from pathlib import Path
import tempfile
import subprocess

import boto3
from botocore.client import Config
from django.conf import settings
from huey import crontab
from huey.contrib.djhuey import periodic_task, task

from core.models import Folder

logger = logging.getLogger(__name__)


def get_s3_client():
    """Get configured S3 client for MinIO"""
    return boto3.client(
        's3',
        endpoint_url=settings.AWS_S3_ENDPOINT_URL,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        config=Config(signature_version='s3v4'),
        region_name=settings.AWS_S3_REGION_NAME
    )


def calculate_sha256(file_path):
    """Calculate SHA256 hash of file"""
    sha256 = hashlib.sha256()
    with open(file_path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            sha256.update(chunk)
    return sha256.hexdigest()


def upload_to_minio(local_path, bucket, s3_key):
    """Upload file to MinIO and return S3 URL and hash"""
    try:
        s3_client = get_s3_client()
        
        # Calculate hash before upload
        file_hash = calculate_sha256(local_path)
        
        # Upload with metadata
        with open(local_path, 'rb') as f:
            s3_client.put_object(
                Bucket=bucket,
                Key=s3_key,
                Body=f,
                Metadata={
                    'sha256': file_hash,
                    'uploaded_at': datetime.utcnow().isoformat(),
                    'collector': 'hma-evidence-collector'
                }
            )
        
        s3_url = f"s3://{bucket}/{s3_key}"
        logger.info(f"Uploaded {local_path} to {s3_url} (SHA256: {file_hash[:16]}...)")
        
        return s3_url, file_hash
        
    except Exception as e:
        logger.error(f"Failed to upload to MinIO: {e}")
        raise


def create_evidence_record(title, description, s3_url, file_hash, evidence_type="automated", folder_name="Infrastructure Evidence"):
    """Create evidence record in CISO Assistant database"""
    try:
        # Get or create evidence folder
        folder, created = Folder.objects.get_or_create(
            name=folder_name,
            defaults={
                'description': 'Automatically collected infrastructure evidence',
                'content_type': Folder.ContentType.DOMAIN
            }
        )
        
        # Create applied control evidence (simplified - adjust to your model)
        # NOTE: This is a placeholder - actual implementation depends on CISO Assistant's evidence model
        logger.info(f"Evidence record created: {title}")
        logger.info(f"  S3 URL: {s3_url}")
        logger.info(f"  SHA256: {file_hash}")
        logger.info(f"  Folder: {folder.name}")
        
        # TODO: Create actual evidence model instance when structure is confirmed
        # Example:
        # from core.models import Evidence
        # evidence = Evidence.objects.create(
        #     title=title,
        #     description=description,
        #     file_url=s3_url,
        #     file_hash=file_hash,
        #     folder=folder,
        #     evidence_type=evidence_type,
        #     collected_at=datetime.utcnow()
        # )
        
        return True
        
    except Exception as e:
        logger.error(f"Failed to create evidence record: {e}")
        return False


@periodic_task(crontab(minute='*/5'))
def collect_docker_inventory():
    """
    Collect Docker container inventory every 5 minutes
    
    Evidence collected:
    - Running containers with images, ports, networks
    - Container resource usage
    - Network configuration
    """
    try:
        logger.info("Collecting Docker inventory...")
        
        # Get docker inventory using docker CLI
        result = subprocess.run(
            ['docker', 'ps', '--format', '{{json .}}'],
            capture_output=True,
            text=True,
            check=True
        )
        
        containers = [json.loads(line) for line in result.stdout.strip().split('\n') if line]
        
        # Create comprehensive inventory
        inventory = {
            'timestamp': datetime.utcnow().isoformat(),
            'collector': 'docker_inventory',
            'total_containers': len(containers),
            'containers': containers
        }
        
        # Save to temp file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(inventory, f, indent=2)
            temp_path = f.name
        
        try:
            # Upload to MinIO
            timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
            s3_key = f"infrastructure/docker/inventory_{timestamp}.json"
            s3_url, file_hash = upload_to_minio(
                temp_path,
                'hma-compliance-evidence',
                s3_key
            )
            
            # Create evidence record
            create_evidence_record(
                title=f"Docker Inventory - {datetime.utcnow().strftime('%Y-%m-%d %H:%M')}",
                description=f"Automated Docker container inventory snapshot. {len(containers)} containers running.",
                s3_url=s3_url,
                file_hash=file_hash,
                evidence_type="automated"
            )
            
            logger.info(f"✅ Docker inventory collected: {len(containers)} containers")
            
        finally:
            # Clean up temp file
            Path(temp_path).unlink()
            
    except subprocess.CalledProcessError as e:
        logger.error(f"Docker command failed: {e}")
    except Exception as e:
        logger.error(f"Docker inventory collection failed: {e}")


@periodic_task(crontab(hour='2', minute='0'))
def collect_database_schema():
    """
    Collect PostgreSQL database schema daily at 2 AM
    
    Evidence collected:
    - Table definitions
    - Index configuration
    - Foreign key constraints
    - User permissions
    """
    try:
        logger.info("Collecting PostgreSQL schema...")
        
        # Get schema dump
        result = subprocess.run(
            [
                'docker', 'exec', 'hma_postgres',
                'pg_dump', '-U', 'hma_admin', '--schema-only', 'hma_academy'
            ],
            capture_output=True,
            text=True,
            check=True
        )
        
        schema_sql = result.stdout
        
        # Save to temp file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.sql', delete=False) as f:
            f.write(schema_sql)
            temp_path = f.name
        
        try:
            # Upload to MinIO
            timestamp = datetime.utcnow().strftime('%Y%m%d')
            s3_key = f"infrastructure/database/schema_{timestamp}.sql"
            s3_url, file_hash = upload_to_minio(
                temp_path,
                'hma-compliance-evidence',
                s3_key
            )
            
            # Create evidence record
            create_evidence_record(
                title=f"Database Schema - {datetime.utcnow().strftime('%Y-%m-%d')}",
                description="PostgreSQL database schema dump for hma_academy database",
                s3_url=s3_url,
                file_hash=file_hash,
                evidence_type="automated"
            )
            
            logger.info(f"✅ Database schema collected ({len(schema_sql)} bytes)")
            
        finally:
            Path(temp_path).unlink()
            
    except subprocess.CalledProcessError as e:
        logger.error(f"Database schema dump failed: {e}")
    except Exception as e:
        logger.error(f"Database schema collection failed: {e}")


@periodic_task(crontab(hour='3', minute='0'))
def collect_network_configuration():
    """
    Collect Docker network configuration daily at 3 AM
    
    Evidence collected:
    - Network topology
    - IP assignments
    - DNS configuration
    - Service discovery
    """
    try:
        logger.info("Collecting network configuration...")
        
        # Get network inspect
        result = subprocess.run(
            ['docker', 'network', 'inspect', 'hma-network'],
            capture_output=True,
            text=True,
            check=True
        )
        
        network_config = json.loads(result.stdout)
        
        # Create comprehensive network report
        report = {
            'timestamp': datetime.utcnow().isoformat(),
            'collector': 'network_configuration',
            'network': network_config[0]
        }
        
        # Save to temp file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(report, f, indent=2)
            temp_path = f.name
        
        try:
            # Upload to MinIO
            timestamp = datetime.utcnow().strftime('%Y%m%d')
            s3_key = f"infrastructure/network/config_{timestamp}.json"
            s3_url, file_hash = upload_to_minio(
                temp_path,
                'hma-compliance-evidence',
                s3_key
            )
            
            # Create evidence record
            create_evidence_record(
                title=f"Network Configuration - {datetime.utcnow().strftime('%Y-%m-%d')}",
                description="Docker network topology and configuration",
                s3_url=s3_url,
                file_hash=file_hash,
                evidence_type="automated"
            )
            
            logger.info("✅ Network configuration collected")
            
        finally:
            Path(temp_path).unlink()
            
    except subprocess.CalledProcessError as e:
        logger.error(f"Network inspection failed: {e}")
    except Exception as e:
        logger.error(f"Network configuration collection failed: {e}")


@task()
def collect_manual_evidence(title, description, file_path):
    """
    Manual evidence upload task
    
    Usage:
        from tasks.collectors import collect_manual_evidence
        collect_manual_evidence(
            "Security Scan Report",
            "Nessus vulnerability scan results",
            "/path/to/scan_results.pdf"
        )
    """
    try:
        logger.info(f"Uploading manual evidence: {title}")
        
        if not Path(file_path).exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        
        # Upload to MinIO
        timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
        filename = Path(file_path).name
        s3_key = f"evidence/manual/{timestamp}_{filename}"
        
        s3_url, file_hash = upload_to_minio(
            file_path,
            'hma-compliance-evidence',
            s3_key
        )
        
        # Create evidence record
        create_evidence_record(
            title=title,
            description=description,
            s3_url=s3_url,
            file_hash=file_hash,
            evidence_type="manual"
        )
        
        logger.info(f"✅ Manual evidence uploaded: {title}")
        return s3_url
        
    except Exception as e:
        logger.error(f"Manual evidence upload failed: {e}")
        raise

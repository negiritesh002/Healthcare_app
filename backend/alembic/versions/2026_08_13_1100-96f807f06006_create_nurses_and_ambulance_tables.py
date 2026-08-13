"""create nurses and ambulance tables and seed sample data

Revision ID: 96f807f06006
Revises: 85f706e95005
Create Date: 2026-08-13 11:00:00.000000

"""
import uuid
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = '96f807f06006'
down_revision: Union[str, None] = '85f706e95005'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create nurses table
    op.create_table(
        'nurses',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('full_name', sa.String(length=255), nullable=False),
        sa.Column('ward_department', sa.String(length=255), nullable=False),
        sa.Column('duty_status', sa.String(length=50), server_default='available', nullable=False),
        sa.Column('phone', sa.String(length=50), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # 2. Create nurse_assignments table
    op.create_table(
        'nurse_assignments',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('nurse_id', UUID(as_uuid=True), sa.ForeignKey('nurses.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('patient_id', UUID(as_uuid=True), sa.ForeignKey('patients.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('doctor_id', UUID(as_uuid=True), sa.ForeignKey('doctors.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('assigned_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('notes', sa.String(length=1000), nullable=True),
    )

    # 3. Create ambulances table
    op.create_table(
        'ambulances',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('unit_code', sa.String(length=100), unique=True, nullable=False),
        sa.Column('status', sa.String(length=50), server_default='available', nullable=False),
        sa.Column('current_location', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # 4. Create dispatch_requests table
    op.create_table(
        'dispatch_requests',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('ambulance_id', UUID(as_uuid=True), sa.ForeignKey('ambulances.id', ondelete='SET NULL'), nullable=True, index=True),
        sa.Column('patient_id', UUID(as_uuid=True), sa.ForeignKey('patients.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('doctor_id', UUID(as_uuid=True), sa.ForeignKey('doctors.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('pickup_location', sa.String(length=500), nullable=False),
        sa.Column('status', sa.String(length=50), server_default='pending', nullable=False),
        sa.Column('requested_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # 5. Seed sample nurses
    nurses_table = sa.table(
        'nurses',
        sa.column('id', UUID(as_uuid=True)),
        sa.column('full_name', sa.String),
        sa.column('ward_department', sa.String),
        sa.column('duty_status', sa.String),
        sa.column('phone', sa.String),
    )

    sample_nurses = [
        {"id": str(uuid.uuid4()), "full_name": "Sarah Jenkins", "ward_department": "Cardiology Ward - Floor 3", "duty_status": "available", "phone": "+15551112222"},
        {"id": str(uuid.uuid4()), "full_name": "Marcus Thorne", "ward_department": "Emergency ER - Bay 1", "duty_status": "available", "phone": "+15552223333"},
        {"id": str(uuid.uuid4()), "full_name": "Elena Rodriguez", "ward_department": "Pediatrics - Floor 2", "duty_status": "busy", "phone": "+15553334444"},
        {"id": str(uuid.uuid4()), "full_name": "David Chen", "ward_department": "ICU - Unit B", "duty_status": "available", "phone": "+15554445555"},
        {"id": str(uuid.uuid4()), "full_name": "Maya Patel", "ward_department": "Neurology Ward - Floor 4", "duty_status": "off_duty", "phone": "+15555556666"},
    ]
    op.bulk_insert(nurses_table, sample_nurses)

    # 6. Seed sample ambulance units
    ambulances_table = sa.table(
        'ambulances',
        sa.column('id', UUID(as_uuid=True)),
        sa.column('unit_code', sa.String),
        sa.column('status', sa.String),
        sa.column('current_location', sa.String),
    )

    sample_ambulances = [
        {"id": str(uuid.uuid4()), "unit_code": "UNIT-A04", "status": "available", "current_location": "Central Station"},
        {"id": str(uuid.uuid4()), "unit_code": "UNIT-B12", "status": "available", "current_location": "North Emergency Bay"},
        {"id": str(uuid.uuid4()), "unit_code": "UNIT-C09", "status": "available", "current_location": "South Trauma Center"},
        {"id": str(uuid.uuid4()), "unit_code": "UNIT-D15", "status": "available", "current_location": "East Station"},
    ]
    op.bulk_insert(ambulances_table, sample_ambulances)


def downgrade() -> None:
    op.drop_table('dispatch_requests')
    op.drop_table('ambulances')
    op.drop_table('nurse_assignments')
    op.drop_table('nurses')

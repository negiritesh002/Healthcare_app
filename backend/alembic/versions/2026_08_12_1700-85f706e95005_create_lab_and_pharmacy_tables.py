"""create lab and pharmacy tables and seed medicines

Revision ID: 85f706e95005
Revises: 74f605d94004
Create Date: 2026-08-12 17:00:00.000000

"""
import uuid
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = '85f706e95005'
down_revision: Union[str, None] = '74f605d94004'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create lab_orders table
    op.create_table(
        'lab_orders',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('doctor_id', UUID(as_uuid=True), sa.ForeignKey('doctors.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('patient_id', UUID(as_uuid=True), sa.ForeignKey('patients.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('test_type', sa.String(length=255), nullable=False),
        sa.Column('status', sa.String(length=50), server_default='pending', nullable=False),
        sa.Column('requested_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('result_notes', sa.String(length=1000), nullable=True),
        sa.Column('result_file_url', sa.String(length=500), nullable=True),
    )

    # 2. Create medicines table
    op.create_table(
        'medicines',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('category', sa.String(length=100), nullable=False),
        sa.Column('unit', sa.String(length=50), nullable=False),
        sa.Column('stock_qty', sa.Integer(), server_default='100', nullable=False),
        sa.Column('low_stock_threshold', sa.Integer(), server_default='20', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # 3. Create prescriptions table
    op.create_table(
        'prescriptions',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('doctor_id', UUID(as_uuid=True), sa.ForeignKey('doctors.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('patient_id', UUID(as_uuid=True), sa.ForeignKey('patients.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('status', sa.String(length=50), server_default='pending_verification', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # 4. Create prescription_items table
    op.create_table(
        'prescription_items',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('prescription_id', UUID(as_uuid=True), sa.ForeignKey('prescriptions.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('medicine_id', UUID(as_uuid=True), sa.ForeignKey('medicines.id', ondelete='RESTRICT'), nullable=False, index=True),
        sa.Column('quantity', sa.Integer(), nullable=False),
    )

    # 5. Seed sample medicines
    medicines_table = sa.table(
        'medicines',
        sa.column('id', UUID(as_uuid=True)),
        sa.column('name', sa.String),
        sa.column('category', sa.String),
        sa.column('unit', sa.String),
        sa.column('stock_qty', sa.Integer),
        sa.column('low_stock_threshold', sa.Integer),
    )

    sample_medicines = [
        {"id": str(uuid.uuid4()), "name": "Amoxicillin 500mg", "category": "Antibiotics", "unit": "Capsules/Strip", "stock_qty": 150, "low_stock_threshold": 20},
        {"id": str(uuid.uuid4()), "name": "Metformin 850mg", "category": "Diabetes", "unit": "Tablets/Box", "stock_qty": 200, "low_stock_threshold": 20},
        {"id": str(uuid.uuid4()), "name": "Lisinopril 10mg", "category": "Cardiovascular", "unit": "Tablets/Box", "stock_qty": 80, "low_stock_threshold": 20},
        {"id": str(uuid.uuid4()), "name": "Atorvastatin 20mg", "category": "Cardiovascular", "unit": "Tablets/Box", "stock_qty": 120, "low_stock_threshold": 20},
        {"id": str(uuid.uuid4()), "name": "Omeprazole 20mg", "category": "Gastrointestinal", "unit": "Capsules/Strip", "stock_qty": 15, "low_stock_threshold": 20},
        {"id": str(uuid.uuid4()), "name": "Paracetamol 500mg", "category": "Analgesics", "unit": "Tablets/Box", "stock_qty": 300, "low_stock_threshold": 30},
        {"id": str(uuid.uuid4()), "name": "Azithromycin 250mg", "category": "Antibiotics", "unit": "Tablets/Box", "stock_qty": 10, "low_stock_threshold": 20},
        {"id": str(uuid.uuid4()), "name": "Ibuprofen 400mg", "category": "Analgesics", "unit": "Tablets/Box", "stock_qty": 180, "low_stock_threshold": 20},
    ]

    op.bulk_insert(medicines_table, sample_medicines)


def downgrade() -> None:
    op.drop_table('prescription_items')
    op.drop_table('prescriptions')
    op.drop_table('medicines')
    op.drop_table('lab_orders')

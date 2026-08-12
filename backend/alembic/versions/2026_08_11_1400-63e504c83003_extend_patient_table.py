"""extend patient table

Revision ID: 63e504c83003
Revises: 52d493b92002
Create Date: 2026-08-11 14:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '63e504c83003'
down_revision: Union[str, None] = '52d493b92002'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('patients', sa.Column('doctor_id', sa.UUID(), nullable=False))
    op.add_column('patients', sa.Column('date_of_birth', sa.String(length=50), nullable=False))
    op.add_column('patients', sa.Column('gender', sa.String(length=20), nullable=False))
    op.add_column('patients', sa.Column('email', sa.String(length=255), nullable=True))
    op.add_column('patients', sa.Column('chief_complaint', sa.String(length=500), nullable=False))
    op.add_column('patients', sa.Column('severity', sa.String(length=20), server_default='low', nullable=False))

    op.create_foreign_key('fk_patients_doctor_id_doctors', 'patients', 'doctors', ['doctor_id'], ['id'], ondelete='CASCADE')
    op.create_index(op.f('ix_patients_doctor_id'), 'patients', ['doctor_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_patients_doctor_id'), table_name='patients')
    op.drop_constraint('fk_patients_doctor_id_doctors', 'patients', type_='foreignkey')
    op.drop_column('patients', 'severity')
    op.drop_column('patients', 'chief_complaint')
    op.drop_column('patients', 'email')
    op.drop_column('patients', 'gender')
    op.drop_column('patients', 'date_of_birth')
    op.drop_column('patients', 'doctor_id')

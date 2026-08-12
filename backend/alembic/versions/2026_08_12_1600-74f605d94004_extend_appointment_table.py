"""extend appointment table

Revision ID: 74f605d94004
Revises: 63e504c83003
Create Date: 2026-08-12 16:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '74f605d94004'
down_revision: Union[str, None] = '63e504c83003'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('appointments', sa.Column('scheduled_at', sa.DateTime(timezone=True), nullable=True))
    # Populate scheduled_at from existing appointment_time
    op.execute("UPDATE appointments SET scheduled_at = appointment_time WHERE scheduled_at IS NULL;")
    op.alter_column('appointments', 'scheduled_at', nullable=False)

    op.add_column('appointments', sa.Column('duration_minutes', sa.Integer(), server_default='30', nullable=False))
    op.add_column('appointments', sa.Column('notes', sa.String(length=500), nullable=True))
    op.alter_column('appointments', 'reason', existing_type=sa.String(length=500), nullable=True)


def downgrade() -> None:
    op.drop_column('appointments', 'notes')
    op.drop_column('appointments', 'duration_minutes')
    op.drop_column('appointments', 'scheduled_at')

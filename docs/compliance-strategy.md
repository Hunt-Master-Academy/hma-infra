
# Compliance Strategy

## Regulatory Scope
- **COPPA**: Age gating, parental consent, and data minimization for users under 18.
- **GDPR**: Data subject rights, consent management, and data portability for EU users.
- **State Regulations**: Hunting license data, reporting, and privacy for US states.

## Implementation
- **Age-Gated Access**: Enforced at auth and registration; audit logs for all access attempts.
- **Consent Management**: Legal acceptance tables in DB; opt-in/opt-out tracked per user.
- **Data Minimization**: Only required fields stored; regular purges of stale data.
- **Audit Logging**: Partitioned audit tables; monthly rotation; breach log for incidents.

## Compliance Operations
- Data export and deletion scripts for user requests
- Regular compliance reviews and automated tests
- Documentation of all compliance-relevant changes

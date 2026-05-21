/**
 * ApprovalCriteriaEvaluator
 * ──────────────────────────────────────────────────────────────────────────────
 * Stateless rule engine that evaluates a list of Approval_Criteria__c rows
 * against an SObject record (and its prior state for change-detection operators).
 *
 * Logic model
 *   • Criteria sharing the same Logic_Group__c are AND-ed together.
 *   • Different groups are OR-ed: (G1C1 AND G1C2) OR (G2C1 AND G2C2).
 *   • No criteria → always returns true (unconditional process).
 *
 * Supported operators (Operator__c)
 *   Text/Picklist : Equals, Not Equals, Contains, Starts With, In, Not In
 *   Number        : Equals, Not Equals, Greater Than, Less Than,
 *                   Greater or Equal, Less or Equal
 *   Boolean       : Equals, Not Equals
 *   Date/DateTime : Equals, Not Equals, Greater Than, Less Than,
 *                   Greater or Equal, Less or Equal
 *   Any type      : Is Null, Is Not Null, Changed, Changed To
 *
 * Cross-object fields
 *   Use dot notation in Field_API_Name__c (e.g. Account.Industry).
 *   The caller (ApprovalProcessEvaluator) is responsible for ensuring the
 *   parent SObject is populated on the record before calling evaluate().
 */
public with sharing class ApprovalCriteriaEvaluator {

    // ── Public entry point ────────────────────────────────────────────────────

    /**
     * @param record     The current (new) SObject to evaluate.
     * @param oldRecord  The previous state of the record (null on insert).
     * @param criteria   Ordered list of Approval_Criteria__c for one process.
     * @return           True if the record satisfies the overall criteria logic.
     */
    public static Boolean evaluate(
        SObject record,
        SObject oldRecord,
        List<Approval_Criteria__c> criteria
    ) {
        if (criteria == null || criteria.isEmpty()) return true;

        // Bucket criteria into logic groups
        Map<Decimal, List<Approval_Criteria__c>> groups =
            new Map<Decimal, List<Approval_Criteria__c>>();

        for (Approval_Criteria__c c : criteria) {
            Decimal grp = c.Logic_Group__c != null ? c.Logic_Group__c : 1;
            if (!groups.containsKey(grp)) {
                groups.put(grp, new List<Approval_Criteria__c>());
            }
            groups.get(grp).add(c);
        }

        // OR across groups; each group is internally AND-ed
        for (Decimal grp : groups.keySet()) {
            if (evaluateGroup(record, oldRecord, groups.get(grp))) return true;
        }
        return false;
    }

    // ── Group / single-criterion evaluation ──────────────────────────────────

    private static Boolean evaluateGroup(
        SObject record,
        SObject oldRecord,
        List<Approval_Criteria__c> criteria
    ) {
        for (Approval_Criteria__c c : criteria) {
            if (!evaluateSingle(record, oldRecord, c)) return false;
        }
        return true;
    }

    private static Boolean evaluateSingle(
        SObject record,
        SObject oldRecord,
        Approval_Criteria__c c
    ) {
        try {
            Object newVal  = getFieldValue(record, c.Field_API_Name__c);
            String  op     = c.Operator__c;

            // ── Null-check operators ──────────────────────────────────────────
            if (op == 'Is Null')     return newVal == null;
            if (op == 'Is Not Null') return newVal != null;

            // ── Change-detection operators (require oldRecord) ────────────────
            if (op == 'Changed') {
                Object oldVal = getFieldValue(oldRecord, c.Field_API_Name__c);
                return String.valueOf(newVal) != String.valueOf(oldVal);
            }
            if (op == 'Changed To') {
                Object oldVal = getFieldValue(oldRecord, c.Field_API_Name__c);
                return String.valueOf(newVal) == c.Value__c
                    && String.valueOf(newVal) != String.valueOf(oldVal);
            }

            // ── Type-aware comparison operators ──────────────────────────────
            String fieldType = c.Field_Type__c != null ? c.Field_Type__c : 'Text';
            if (fieldType == 'Number')   return evaluateNumber(newVal, op, c.Value__c);
            if (fieldType == 'Boolean')  return evaluateBoolean(newVal, op, c.Value__c);
            if (fieldType == 'Date')     return evaluateDate(newVal, op, c.Value__c);
            if (fieldType == 'DateTime') return evaluateDateTime(newVal, op, c.Value__c);
            return evaluateText(newVal, op, c.Value__c); // Text / Picklist default

        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN,
                'ApprovalCriteriaEvaluator: criterion ' + c.Id
                + ' threw — ' + ex.getMessage());
            return false;
        }
    }

    // ── Type evaluators ───────────────────────────────────────────────────────

    private static Boolean evaluateText(Object fieldVal, String op, String cmp) {
        String s = fieldVal != null ? String.valueOf(fieldVal) : '';
        if (op == 'Equals')      return s == cmp;
        if (op == 'Not Equals')  return s != cmp;
        if (op == 'Contains')    return s.containsIgnoreCase(cmp);
        if (op == 'Starts With') return s.startsWithIgnoreCase(cmp);
        if (op == 'In') {
            return new Set<String>(cmp.replaceAll('\\s*,\\s*', ',').split(',')).contains(s);
        }
        if (op == 'Not In') {
            return !new Set<String>(cmp.replaceAll('\\s*,\\s*', ',').split(',')).contains(s);
        }
        return false;
    }

    private static Boolean evaluateNumber(Object fieldVal, String op, String cmp) {
        if (fieldVal == null) return false;
        Decimal num = Decimal.valueOf(String.valueOf(fieldVal));
        Decimal ref = Decimal.valueOf(cmp.trim());
        if (op == 'Equals')           return num == ref;
        if (op == 'Not Equals')       return num != ref;
        if (op == 'Greater Than')     return num >  ref;
        if (op == 'Less Than')        return num <  ref;
        if (op == 'Greater or Equal') return num >= ref;
        if (op == 'Less or Equal')    return num <= ref;
        return false;
    }

    private static Boolean evaluateBoolean(Object fieldVal, String op, String cmp) {
        Boolean b   = (Boolean) fieldVal;
        Boolean ref = Boolean.valueOf(cmp);
        if (op == 'Equals')     return b == ref;
        if (op == 'Not Equals') return b != ref;
        return false;
    }

    private static Boolean evaluateDate(Object fieldVal, String op, String cmp) {
        if (fieldVal == null) return false;
        Date d   = (Date) fieldVal;
        Date ref = Date.valueOf(cmp.trim());
        if (op == 'Equals')           return d == ref;
        if (op == 'Not Equals')       return d != ref;
        if (op == 'Greater Than')     return d >  ref;
        if (op == 'Less Than')        return d <  ref;
        if (op == 'Greater or Equal') return d >= ref;
        if (op == 'Less or Equal')    return d <= ref;
        return false;
    }

    private static Boolean evaluateDateTime(Object fieldVal, String op, String cmp) {
        if (fieldVal == null) return false;
        DateTime dt  = (DateTime) fieldVal;
        DateTime ref = DateTime.valueOf(cmp.trim());
        if (op == 'Equals')           return dt == ref;
        if (op == 'Not Equals')       return dt != ref;
        if (op == 'Greater Than')     return dt >  ref;
        if (op == 'Less Than')        return dt <  ref;
        if (op == 'Greater or Equal') return dt >= ref;
        if (op == 'Less or Equal')    return dt <= ref;
        return false;
    }

    // ── Field accessor — supports dot notation for parent relationships ────────

    private static Object getFieldValue(SObject record, String fieldApiName) {
        if (record == null) return null;
        if (!fieldApiName.contains('.')) {
            return record.get(fieldApiName);
        }
        // Recurse: Account.Industry → getSObject('Account').get('Industry')
        Integer dot     = fieldApiName.indexOf('.');
        String  relName = fieldApiName.substring(0, dot);
        String  rest    = fieldApiName.substring(dot + 1);
        SObject parent  = (SObject) record.getSObject(relName);
        return getFieldValue(parent, rest);
    }
}

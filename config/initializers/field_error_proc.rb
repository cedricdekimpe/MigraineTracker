# Rails wraps every form control that has an error in <div class="field_with_errors">.
# The entry form styles its chips with `peer` / `peer-checked`, which needs the input to sit right
# before its label span; the wrapper breaks that and the chips stop reacting. Errors are shown in the
# summary at the top of the form (shared/_form_errors), so the controls are left untouched.
ActionView::Base.field_error_proc = proc { |html_tag, _instance| html_tag }

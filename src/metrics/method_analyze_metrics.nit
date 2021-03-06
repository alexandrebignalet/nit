# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# This module call visitor for get number of line, total attributs call and total of self attributes call

module method_analyze_metrics

# We usualy need specific phases
# NOTE: `frontend` is sufficent in most case (it is often too much)
import metrics_base
import mclasses_metrics
import semantize
import mclassdef_collect


fun call_analyze_methods(mclassdef: MClassDef, model_builder: ModelBuilder): Array[MMethodDef] do
	var mmethoddefs = new Array[MMethodDef]
	for m_prop in mclassdef.collect_intro_and_redef_mpropdefs(model_builder.model.private_view) do
		var n_prop = model_builder.mpropdef2node(m_prop)
		#Check if the property is a method definition
		if n_prop isa AMethPropdef and m_prop isa MMethodDef then
			if n_prop.n_methid isa AIdMethid then
				#Call visitor to analyse the method
				var visitor = new MethodAnalyzeMetrics(n_prop)
				visitor.enter_visit(n_prop)
				mmethoddefs.add(set_analyse_result_methoddef(m_prop,visitor))
			end
		end
	end
	return mmethoddefs
end

fun set_analyse_result_methoddef(mmethoddef: MMethodDef, visitor: MethodAnalyzeMetrics): MMethodDef do
	mmethoddef.total_call = visitor.total_call
	mmethoddef.line_number = visitor.line_number.length
	mmethoddef.total_self_call = visitor.total_self_call
	mmethoddef.total_extern_call = visitor.total_call - visitor.total_self_call
	return mmethoddef
end

public class MethodAnalyzeMetrics
	super Visitor
	var ameth_prop_def: AMethPropdef
	var total_call = 0
	var line_number = new Counter[nullable Int]
	var total_self_call = 0

	redef fun visit(n) do
		n.visit_all(self)
		if n isa AExpr then
			if not n isa ABlockExpr then
				if n.first_location != null then
					line_number.inc(n.first_location.line_start)
				end
			end
		end

		if n isa ASendExpr then
			var callsite = n.callsite
			if callsite != null then
				self.total_call += 1
				if callsite.recv_is_self == true then self.total_self_call += 1
			end
		end
	end
end

redef class MMethodDef
	var total_call = 0
	var line_number = 0
	var total_self_call = 0
	var total_extern_call = 0
end

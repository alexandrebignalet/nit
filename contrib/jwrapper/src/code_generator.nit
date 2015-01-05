# This file is part of NIT (http://www.nitlanguage.org).
#
# Copyright 2014 Frédéric Vachon <fredvac@gmail.com>
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

# Services to generate extern class `in "Java"`
module code_generator

intrude import types

class CodeGenerator

	var with_attributes: Bool
	var comment_unknown_types: Bool
	var file_out: OFStream
	var java_class: JavaClass
	var nb_params: Int
	var module_name: String
	fun code_warehouse: CodeWarehouse do return once new CodeWarehouse

	init (file_name: String, jclass: JavaClass, with_attributes, comment: Bool)
	do
		file_out = new OFStream.open(file_name)
		module_name = file_name.substring(0, file_name.search(".nit").from)
		self.java_class = jclass
		self.with_attributes = with_attributes
		self.comment_unknown_types = comment
	end

	fun generate
	do
		var jclass = self.java_class

		var class_content = new Array[String]
		class_content.add(gen_class_header(jclass.class_type))

		if with_attributes then
			for id, jtype in jclass.attributes do class_content.add(gen_attribute(id, jtype))
		end

		for id, methods_info in jclass.methods do
			for method_info in methods_info do
				var nid = id
				if methods_info.length > 1 then nid += "{methods_info.index_of(method_info)}"
				class_content.add gen_method(id, nid, method_info.return_type, method_info.params)
			end
		end
		class_content.add("\nend\n")

		var wrappers = new Array[String]
		for jtype in jclass.unknown_types do
			if jtype == jclass.class_type then continue
			wrappers.add("\n")
			wrappers.add(gen_unknown_class_header(jtype))
		end

		var imports = new Array[String]
		imports.add("import mnit_android\n")
		for import_ in jclass.imports do
			imports.add("import android::{import_}\n")
		end

		file_out.write(gen_licence)
		file_out.write("module {module_name}\n")
		file_out.write(imports.join(""))
		file_out.write("\n")
		file_out.write(class_content.join(""))
		file_out.write(wrappers.join(""))
	end

	fun gen_licence: String
	do
		return """# This file is part of NIT (http://www.nitlanguage.org).
#
# Copyright [Year] [Author name] <Author e-mail>
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

# This code has been generated using `javap`
"""
	end

	fun gen_class_header(jtype: JavaType): String
	do
		var temp = new Array[String]
		temp.add("extern class Native{jtype.id} in \"Java\" `\{ {jtype} `\}\n")
		temp.add("\tsuper JavaObject\n\tredef type SELF: Native{jtype.id}\n\n")

		return temp.join("")
	end

	fun gen_unknown_class_header(jtype: JavaType): String
	do
		var nit_type: NitType
		if jtype.extern_name.has_generic_params then
			nit_type = jtype.extern_name.generic_params.first
		else
			nit_type = jtype.extern_name
		end

		var temp = new Array[String]
		temp.add("extern class {nit_type} in \"Java\" `\{ {jtype.to_package_name} `\}\n")
		temp.add("\tsuper JavaObject\n\tredef type SELF: {nit_type}\n\nend\n")

		return temp.join("")
	end

	fun gen_attribute(jid: String, jtype: JavaType): String
	do
		return "\tvar {jid.to_snake_case}: {jtype.to_nit_type}\n"
	end
	
	fun gen_method(jmethod_id: String, nmethod_id: String, jreturn_type: JavaType, jparam_list: Array[JavaType]): String
	do
		var java_params = ""
		var nit_params  = ""
		var nit_id = "arg"
		var nit_id_no = 0
		var nit_types = new Array[NitType]
		var comment = "" 

		# Parameters
		for i in [0..jparam_list.length[ do
			var jparam = jparam_list[i]
			var nit_type = jparam.to_nit_type

			if not nit_type.is_complete then
				if jparam.is_wrapped then
					java_class.imports.add nit_type.mod.as(not null)
				else
					if comment_unknown_types then
						comment = "#"
					else
						nit_type = jparam.extern_name
						java_class.unknown_types.add(jparam)
					end
				end
			end

			var cast = ""

			if not jparam.is_collection then cast = jparam.param_cast

			nit_types.add(nit_type)
			nit_type.arg_id = "{nit_id}{nit_id_no}"

			if i == jparam_list.length - 1 then
				java_params += "{cast}{nit_id}{nit_id_no}"
				nit_params  += "{nit_id}{nit_id_no}: {nit_type}"
			else
				java_params += "{cast}{nit_id}{nit_id_no}" + ", "
				nit_params  += "{nit_id}{nit_id_no}: {nit_type}, "
			end

			nit_id_no += 1
		end

		# Method identifier
		var method_id = nmethod_id.to_snake_case
		var nit_signature = new Array[String]

		nit_signature.add "\tfun {method_id}"

		if not jparam_list.is_empty then
			nit_signature.add "({nit_params})"
		end

		var return_type = null

		if not jreturn_type.is_void then
			return_type = jreturn_type.to_nit_type

			if not return_type.is_complete then
				if jreturn_type.is_wrapped then
					java_class.imports.add return_type.mod.as(not null)
				else
					if comment_unknown_types then
						comment = "#"
					else
						return_type = jreturn_type.extern_name
						java_class.unknown_types.add(jreturn_type)
					end
				end
			end

			nit_signature.add ": {return_type} "
		end

		var temp = new Array[String]

		temp.add(comment + nit_signature.join(""))

		# FIXME : This huge `if` block is only necessary to copy primitive arrays as long as there's no better way to do it
		if comment == "#" then
			temp.add(" in \"Java\" `\{\n{comment}\t\trecv.{jmethod_id}({java_params});\n{comment}\t`\}\n")
		# Methods with return type
		else if return_type != null then
			temp.add(" in \"Java\" `\{\n{comment}\t\treturn {jreturn_type.return_cast} recv.{jmethod_id}({java_params});\n{comment}\t`\}\n")
		# Methods without return type
		else if jreturn_type.is_void then
			temp.add(" in \"Java\" `\{\n{comment}\t\trecv.{jmethod_id}({java_params});\n{comment}\t`\}\n")
		# No copy
		else
			temp.add(" in \"Java\" `\{\n{comment}\t\trecv.{jmethod_id}({java_params});\n{comment}\t`\}\n")
		end

		return temp.join("")
	end
end

# Contains raw code mostly used to copy collections
class CodeWarehouse

	private fun create_imports(nit_type: NitType, is_param: Bool): String
	do
		var imports = ""
		var ntype = nit_type.to_s
		var gen_type = nit_type.generic_params.join(", ")

		if not is_param then
			if nit_type.is_map then
				imports = """ import {{{ntype}}}, {{{ntype}}}.[]="""
			else
				imports = """ import {{{ntype}}}, {{{ntype}}}.add"""
			end
		else if nit_type.id == "Array" then
			imports = """ import {{{ntype}}}, {{{ntype}}}.length, {{{ntype}}}.[]"""
		else if nit_type.is_map then
			imports = """ import {{{ntype}}}.iterator, Iterator[{{{gen_type}}}].is_ok, Iterator[{{{gen_type}}}].next, Iterator[{{{gen_type}}}].item, Iterator[{{{gen_type}}}].key"""
		else
			imports = """ import {{{ntype}}}.iterator, Iterator[{{{gen_type}}}].is_ok, Iterator[{{{gen_type}}}].next, Iterator[{{{gen_type}}}].item"""
		end
		
		return imports
	end

	private fun create_loop(java_type: JavaType, nit_type: NitType, is_param: Bool, jarray_id, narray_id: String): String
	do
		var loop_header = ""
		var loop_body = ""
		var gen_type = nit_type.generic_params.join("_")

		if is_param then
			if java_type.is_primitive_array then
				loop_header = "for(int i=0; i < {jarray_id}.length; ++i)"
				loop_body   = """\t\t\t{{{jarray_id}}}[i] = {{{java_type.param_cast}}}Array_of_{{{gen_type}}}__index({{{nit_type.arg_id}}}, i);"""
			else if nit_type.id == "Array" then
				loop_header = """int length = Array_of_{{{gen_type}}}_length((int){{{nit_type.arg_id}}});\n\t\tfor(int i=0; i < length; ++i)"""
				loop_body   = """\t\t\t{{{jarray_id}}}.add({{{java_type.param_cast}}}Array_of_{{{gen_type}}}__index({{{narray_id}}}, i));"""
			else
				loop_header = """int itr = {{{nit_type.id}}}_of_{{{gen_type}}}_iterator({{{nit_type.arg_id}}});\n\t\twhile(Iterator_of_{{{gen_type}}}_is_ok(itr)) {"""
				if nit_type.is_map then
					var key_cast = java_type.to_cast(java_type.generic_params[0].id, true)
					var value_cast = java_type.to_cast(java_type.generic_params[1].id, true)
					loop_body   = """\t\t\t{{{jarray_id}}}[{{{key_cast}}}iterator_of_{{{nit_type.id}}}_key(itr)] = {{{value_cast}}}iterator_of_{{{nit_type.id}}}_item(itr);\n\t\t\titerator_of_{{{gen_type}}}_next(itr);\n\t\t}"""
				else
					loop_body   = """\t\t\t{{{jarray_id}}}.add({{{java_type.param_cast}}}iterator_of_{{{nit_type.id}}}_item(itr));\n\t\t\titerator_of_{{{gen_type}}}_next(itr);\n\t\t}"""
				end
			end
		else
			if nit_type.is_map then
				var key_cast = java_type.to_cast(java_type.generic_params[0].id, false)
				var value_cast = java_type.to_cast(java_type.generic_params[1].id, false)
				loop_header = """for (java.util.Map.Entry<{{{java_type.generic_params[0]}}}, {{{java_type.generic_params[1]}}}> e: {{{jarray_id}}})"""
				loop_body   = """\t\t\t{{{nit_type.id}}}_of_{{{gen_type}}}_{{{nit_type.generic_params[1]}}}__index_assign({{{narray_id}}}, {{{key_cast}}}e.getKey(), {{{value_cast}}}e.getValue());"""
			else if java_type.is_iterable then
				loop_header = """for ({{{java_type.generic_params[0]}}} e: {{{jarray_id}}})"""
				loop_body   = """\t\t\t{{{nit_type.id}}}_of_{{{gen_type}}}_add({{{narray_id}}}, {{{java_type.return_cast}}}e);"""
			else
				loop_header = "for(int i=0; i < {jarray_id}.length; ++i)"
				loop_body   = """\t\t\t{{{nit_type.id}}}_of_{{{gen_type}}}_add({{{narray_id}}}, {{{java_type.return_cast}}}{{{jarray_id}}}[i]);"""
			end
		end

		return loop_header + "\n" + loop_body
	end
end

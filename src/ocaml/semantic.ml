open Ast;;
open Str;;

exception Error of string
exception Variable_not_defined of string

module StringMap = Map.Make(String);;

type symbol_table = { 
  mutable table : string StringMap.t;
  mutable parent: symbol_table option; 
  mutable children : symbol_table list;
  mutable pure : bool
} 

(* utility function *)
let debug str = 
  if true then print_string (str) else ()

let rec lookup id sym_table iter = 
  debug("Looking for "^ id ^" ...\n");
  try 
    let t = StringMap.find id sym_table.table in 
  debug("Found " ^ id ^ " ...\n");
    (t, iter) 
  with Not_found ->
    match sym_table.parent with 
    | Some(parent) -> lookup id parent (iter +1 )
    | _ -> raise Not_found 

let add_to_symbol_table id id_type sym_table = 
  debug("Adding " ^ id ^ " to symbol_table \n");
  sym_table.table <- StringMap.add id id_type sym_table.table;
  ()
  
let make_symbol_table p_table = 
  debug("Making a symbol_table... \n");
  let s_table = {
    table = StringMap.empty;
    parent = Some(p_table);
    children = [];
    pure = false;
  } in
  ignore(p_table.children <- s_table :: p_table.children);
  s_table 

(* This method is very experimental *)
(*let rec get_symbol_table root id iter = *)
  (*let rec wrap_get_sym_table root id iter tail = *)
    (*(try ignore(StringMap.find id root.table);*)
      (*root*)
    (*with Not_found ->*)
      (*(match tail with *)
      (*| [] ->    *)
      (*| h :: tl -> wrap_get_sym_table h id (iter+1) tl))*)
  (*in*)
  (*try*)
    (*ignore(StringMap.find id root.table);*)
    (*root*)
  (*with Not_found ->*)
    (*match root.children with*)
    (*| [] -> raise (Not_found)*)
    (*| h :: tl -> wrap_get_sym_table h id (iter+1) tl*)

let ht = Hashtbl.create 100;;
(***************************************************************************)
let rec check_expression e sym_tabl = 
  debug("Checking an expression... \n");
  (match e with 
  | Assignment_expression (left, right) ->
    (match left with
      | Variable(v) ->
        let (t, iter) = lookup v sym_tabl 0 in
        let t1 = get_type right sym_tabl in
        ignore(compare_type t t1);
        t1 
      | Array_access(name, index) ->
        (match name with 
          | Variable(v) -> 
            let (t, iter) = lookup v sym_tabl 0 in
            let index_t = get_type index sym_tabl in
            if index_t <> "Number" then raise (Error "Invalid Array Access")
            else begin 
              let t1 = get_type right sym_tabl in
              ignore(compare_type t t1);
              t1
            end
          | _ -> raise (Error "Malformed Array Statement"))
       | _ -> raise (Error "Invalid Assignment Expression")
    )
  | Declaration (var_type, var) ->
    (match var with
      | Variable(v) ->
        (try
          ignore(lookup v sym_tabl 0);
          raise (Error "Variable previously defined");
        with Not_found ->
          let t1 = check_var_type var_type in
          if t1 = "Void" then raise 
            (Error "Cannot declare a variable of type void")  
          else begin
            ignore(add_to_symbol_table v t1 sym_tabl);
            t1
          end
        )
      | _ -> raise (Error "Invalid Declaration Type")
    ) 
  | Declaration_expression (var_type, var, right) ->
    (match var with
      | Variable(v) -> 
          (try
            ignore(lookup v sym_tabl 0);
            raise (Error "Variable perviously defined");
          with Not_found ->
            let t = check_var_type var_type in
            let t2 = get_type right sym_tabl in
            ignore(compare_type t t2);
            ignore(add_to_symbol_table v t sym_tabl);
            t2
          )
      | _ -> raise (Error "Malformed Declaration Expression"))
  | Array_literal (exprs) ->
    let get_type_wrap expr = 
      get_type expr sym_tabl
    in
    let t = get_type (List.hd exprs) sym_tabl in
    ignore (List.fold_left compare_type t (List.map get_type_wrap exprs));
    t
  | List_comprehension (expr, params, exprs, expr1, s) -> 
    let symbol_table = make_symbol_table sym_tabl in
    let check_param_table param = check_param param symbol_table in
    let get_type_table e = 
      let temp_str = get_type e symbol_table in
        String.sub temp_str 0 ((String.length temp_str) - 2) in
    (try
      ignore(List.map2 compare_type
        (List.map check_param_table params)
        (List.map get_type_table exprs));
      let t = get_type expr1 symbol_table in
      match t with
        | ""  -> t 
        | "Boolean" -> t 
        | _ -> raise (Error "Bad filter in List Comp")
    with Invalid_argument "" -> raise (Error "Poorly formed List Comp")) 
  | Unop (op, expr) ->
      let t = (get_type expr sym_tabl) in
      ignore(check_unop op t);
      t
  | Binop (expr, op, expr1) -> 
      let t = (get_type expr sym_tabl) in
      let t2 = (get_type expr1 sym_tabl) in
      ignore(check_operator t op t2);
      t2
  | Function_call (expr, exprs) ->
    let get_type_table expr = 
      get_type expr sym_tabl
    in 
    (match expr with
      | Variable(v) ->
          (try
            let (t, iter) = lookup v sym_tabl 0 in 
          ignore (List.map2 compare_type 
                  (Hashtbl.find ht v)
                  (List.map get_type_table exprs));
          t
          with Not_found -> raise (Error "Function not found")
          ) 
      | _ -> raise (Error "Malformed function call")) 
  | Array_access (name, right) -> 
    (match name with 
      | Variable(v) -> 
        let (t, iter) = lookup v sym_tabl 0 in
        let index_t = get_type right sym_tabl in
        if index_t <> "Number" then raise (Error "Invalid Array Access")
        else begin 
        t
        end
      | _ -> raise (Error "Malformed Array Statement"))
  | Variable (v) -> let (t, expr) = lookup v sym_tabl 0 in t 
  | Char_literal (c) -> "Char" 
  | Number_literal (f) -> "Number"
  | String_literal (str) -> "String"
  | Boolean_literal (b) -> "Boolean"
  | Nil_literal -> "Nil"
  | Anonymous_function (var_type, params, stats, s_t) ->
      let check_param_table param = check_param param sym_tabl in 
      ignore(List.map check_param_table params);
      check_var_type var_type
      (* TODO Match Jump Statement with Return Type *)
  | Function_expression (stat) ->
      (match stat with
      | Function_definition(name, ret_type, params, sts, s_t) ->
      ignore(check_func_def name ret_type params sts sym_tabl);
      let t = (check_var_type ret_type) in 
      t
      | _ -> raise (Error "Malformed Function expression"))
  | Empty_expression -> ""
  )

and get_type expression sym_tabl =
  (match expression with 
  | Array_literal (exprs) -> (get_type (List.nth exprs 0) sym_tabl) ^ "[]"
  | List_comprehension (expr, params, exprs, expr1, s_t) -> 
      (get_type expr sym_tabl)
        (* assume the subexpressions match *)
  | Unop (op, expr) ->
      (match op with
      | Neg -> "Number"
      | Not -> "Boolean")
  | Binop (expr, op, expr1) ->
      (match op with
        Add -> "Number"
      | Sub -> "Number"
      | Mult -> "Number"
      | Div -> "Number"
      | Mod -> "Number"
            (* these relational guys shouldn't be just numbers !!! *)
      | Eq -> "Boolean"
      | Neq -> "Boolean"
      | Lt -> "Boolean"
      | Leq -> "Boolean"
      | Gt -> "Boolean"
      | Geq -> "Boolean"
      | And -> "Boolean"
      | Or -> "Boolean")
        (* extract the return value *)
  | Function_call (expr, exprs) -> (* (get_type expr ) *) ""
        (* strip a layer off *)
  | Array_access (expr, expr1) -> (* (get_type expr ) *) ""
        (* get the type from the symbol table *)
  | Variable (v) -> (fst (lookup v sym_tabl 0))
  | Char_literal (c) -> "Char"
  | Number_literal (f) -> "Number"
  | String_literal (str) -> "Char[]"
  | Boolean_literal (b) -> "Boolean"
  | Anonymous_function (var_type, params, stats, s_t) -> ""
  | Function_expression (stat) -> ""
  | Empty_expression -> ""
  | _ -> raise (Error "WHAT THE FUCK IS THIS SHIT")
  )

and compare_type type1 type2 =
  debug ("Comparing two types...\n");
  debug ("Comparing " ^ type1 ^ " with " ^ type2 ^ "\n"); 
  if type1 <> type2 then raise (Error "Type Mismatch")
  else type1

and check_unop op type1 =
  ignore(debug ("Checking a unop ...\n")); 
  (match op with
    Neg -> if (type1 <> "Number") 
            then raise (Error "Operator applied invalid type") else ""
  | Not -> if (type1 <> "Boolean")
            then raise (Error "Operator applied to invalid type") else "")

and check_operator type1 op type2 =
  debug ("Checking an operator...\n");   
  (match op with
    Add ->
      if (type1 <> "Number" or type2 <> "Number")
      then raise (Error "Operator applied invalid type")
  | Sub ->
      if (type1 <> "Number" or type2 <> "Number")
      then raise (Error "Operator applied invalid type")
  | Mult ->
      if (type1 <> "Number" or type2 <> "Number")
      then raise (Error "Operator applied invalid type")
  | Div ->
      if (type1 <> "Number" or type2 <> "Number")
      then raise (Error "Operator applied invalid type")
  | Mod ->
      if (type1 <> "Number" or type2 <> "Number")
      then raise (Error "Operator applied invalid type")
  | Eq ->
      if (type1 <> type2)
      then raise (Error "Types do not match on both sides of the operator")
  | Neq ->
      if (type1 <> type2)
      then raise (Error "Types do not match on both sides of the operator")
  | Lt ->
      if (type1 <> "Number" or type2 <> "Number")
      then raise (Error "Operator applied invalid type")
  | Leq ->
      if (type1 <> "Number" or type2 <> "Number")
      then raise (Error "Operator applied invalid type")
  | Gt ->
      if (type1 <> "Number" or type2 <> "Number")
      then raise (Error "Operator applied invalid type")
  | Geq ->
      if (type1 <> "Number" or type2 <> "Number")
      then raise (Error "Operator applied invalid type")
  | And ->
      if (type1 <> "Boolean" or type2 <> "Boolean")
      then raise (Error "Operator applied invalid type")
  | Or ->
      if (type1 <> "Boolean" or type2 <> "Boolean")
      then raise (Error "Operator applied invalid type"))
  (*| _ -> raise (Error "Unsupported Binary Operator")*)

and check_basic_type btype =
  debug("Checking basic type...\n");
  match btype with
    Void_type -> "Void"
  | Number_type -> "Number"
  | Char_type -> "Char"
  | Boolean_type -> "Boolean"
  (*| _ -> raise (Error "Unsupported Type")*)

and check_var_type var_type : string =
  
  debug("Checking var_types...\n"); 
    
  match var_type with
  |  Basic_type(b) -> (check_basic_type b)
  | Array_type(a) -> 
      let t = (check_var_type a) in
      if t = "Void" then raise 
            (Error "Cannot declare an array of type void")  
          else t ^ "[]"
  | Func_type(ret_type, param_types) ->
      ignore(List.map check_var_type param_types);
      "func_" ^ (check_var_type ret_type);
  | Func_param_type(ret_type, params) ->
  raise (Error "This SHIT IS FUCKED") 
      (*let extract_type param = *)
      (*match param with*)
        (*Param(param_type, varname) -> param_type*)
    (*in*)
    (*let type_list = (List.map extract_type params) in*)
    (*(check_var_type ret_type)*)
    (*(List.map check_param params)*)
  | _ -> raise (Error "Unsupported variable type")

and check_param parm sym_tabl = 
  debug ("Checking params...\n");
  match parm with
    Param(param_type, varname) ->
      match varname with
      | Variable(v) ->
        (let t = check_var_type param_type in
        if t = "Void" then raise 
            (Error "Cannot pass param of type void")  
          else begin 
            ignore(add_to_symbol_table v t sym_tabl);
            t
          end)
      | _ -> raise (Error "Param type invalid")

and check_boolean v = 
  match v with 
  | "Boolean" -> ""
  | _ -> raise (Error "Type found where Boolean expected")

and check_selection select sym_tabl =
  debug ("Checking a selection block... \n");
  ignore(check_boolean (get_type select.if_cond sym_tabl));
  ignore(check_statements select.if_body (make_symbol_table sym_tabl));
  if ((List.length select.elif_conds) != 0) then
    let check_elif cond body = 
      ignore(check_boolean (check_expression select.if_cond sym_tabl));
      ignore(check_statements body (make_symbol_table sym_tabl));
      "" 
    in
    ignore(List.map2 check_elif select.elif_conds select.elif_bodies);
  else begin 
    if (List.length select.else_body) != 0 then 
      ignore(check_statements select.else_body (make_symbol_table sym_tabl)) 
    else () 
  end

and check_iter dec check incr stats sym_tabl = 
  ignore(check_expression dec sym_tabl); 
  if ( (get_type check sym_tabl) <> "Boolean") then 
    raise (Error "Conditonal in iteration not of type Boolean");
    ignore(check_expression incr sym_tabl);
  ignore(check_statements stats (make_symbol_table sym_tabl));

(* TODO 
 * Need to check function type matchs used return type *)
and check_func_def (name : string) ret_type params stats sym_tabl =
  debug ("Checking a func def...\n");
  try
    ignore (lookup name sym_tabl 0);
    raise (Error "Function previously declared")
  with Not_found ->
    let v = check_var_type ret_type in
    ignore(add_to_symbol_table name v sym_tabl); 
    let check_param_table param = check_param param sym_tabl in
    (Hashtbl.add ht name (List.map check_param_table params));
    let com_bools x y = x || y in 
    let rec match_jump_types stat =
      debug ("Looking for jumps in " ^ name ^ "...\n");
    (match stat with
    | Statements(s) ->
        debug("Statements\n");
        List.fold_left 
        com_bools
        false 
        (List.map match_jump_types s) 
    | Selection(s) ->
        debug("Selections\n");
        List.fold_left 
        com_bools 
        false
        (List.map match_jump_types 
        (List.concat [s.if_body; s.else_body; (List.concat s.elif_bodies)]) 
        )
    | Iteration(d,c,i,s, s_t) ->
        debug("Iteration\n");
        List.fold_left 
        com_bools 
        false 
        (List.map match_jump_types s) 
    | Jump(j) ->
        debug("Jumping!\n");
        ignore(compare_type (get_type j sym_tabl) v);
        true
    | Expression(e) -> 
        debug("Expression\n");
        false 
    | _ -> 
        debug("Catch all\n");
        false)
    in
    let b =
      List.fold_left 
        com_bools 
        false 
        (List.map match_jump_types stats)
    in
    if b then debug("True \n") else print_string("False \n"); 
    if b && (v = "Void")  then raise (Error "Void method contains return")
    else if (not b) && (v <> "Void") then raise (Error "Non-void method must
    contain return statement") else v 

and check_statement stat sym_tabl =
  debug ("Checking Statement... \n");
  match stat with
  | Expression(e) -> ignore (check_expression e sym_tabl);
  | Statements(s) -> ignore (check_statements s sym_tabl);
  | Selection(s) -> ignore (check_selection s sym_tabl);
  | Iteration(dec, check, incr, stats, s_t) -> 
      ignore(check_iter dec check incr stats sym_tabl);
  | Jump(j) -> ignore (check_expression j sym_tabl);
  debug ("Check jump...\n");
  | Function_definition(name, ret_type, params, sts, s_t) ->
      ignore(check_func_def name ret_type params sts sym_tabl);
      ignore(check_statements sts sym_tabl);
      (*| _ -> raise (Error "Malformed statement")*)

and check_statements stats sym_tabl =
  debug "Checking Statements... \n";
  match stats with 
  | hd :: tl -> 
      ignore(check_statement hd sym_tabl);
      ignore(check_statements tl sym_tabl);
  | [] -> () 

let generate_sast program = 
  match program with
  | Program(imp, stat) -> 
    let s_table = {
      table = StringMap.empty;
      parent = None;
      children = [];
      pure = false;
    } in
    ignore(check_statements stat s_table)
;;

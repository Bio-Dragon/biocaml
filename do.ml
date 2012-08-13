#! /usr/bin/env ocaml

#use "topfind"
#thread
#require "core"
open Core.Std

open Printf

let command fmt =
  let f x =
    printf "Running %S\n%!" x;
    ignore (Sys.command x)
  in
  ksprintf f fmt

let remove file =
  match Sys.file_exists file with
  | `Yes ->
    Sys.remove file;
    printf "Removed %s\n%!" file;
  | `No | `Unknown -> 
    printf "No %s to remove\n%!" file
      
    
let usage ch =
  fprintf ch "usage: %s {-help,-h,help,<cmd>}\n" Sys.argv.(0)
    
let help_commands = ref []
let add_help name descr = help_commands := (name, descr) :: !help_commands
let help () =
  usage stdout;
  printf "where cmd is:\n";
  List.iter (List.rev !help_commands) (fun (name, descr) ->
    printf "  %s\n    " name;
    String.iter ~f:(function '\n' -> printf "    \n" | c -> printf "%c" c) descr;
    printf "\n"
  );
  ()
    
let check_cwd () =
  if Sys.file_exists "_oasis" = `No then
    failwith "Wrong working directory: There is no _oasis file"
  
let setup_clean () =
  check_cwd ();
  command "oasis setup-clean";
  remove "myocamlbuild.ml";
  remove "setup.data";
  remove "setup.log";
  remove "_tags";
  remove "Makefile";
  remove "configure";
  remove "src/lib/META";
  remove "src/lib/libbiocaml_stubs.clib";
  remove "src/lib/doclib.odocl";
  remove "src/lib/biocaml.mllib";
  remove "setup.ml";
  remove "TAGS"

  
let setup () =
  check_cwd ();
  setup_clean ();
  command "oasis setup";
  command "echo 'true: annot' >> _tags";
  command "cat src/etc/Makefile.post >> Makefile"

let ocaml_toplevel () =
  let tmp = Filename.temp_file "ocamlinit" ".ml" in
  let o = open_out tmp in
  fprintf o "
#use \"topfind\";;
#thread;;
#require \"core, camlzip, sqlite3, unix, batteries, xmlm\"
#directory \"_build/src/lib\";;
#load \"biocaml.cma\";;
open Core.Std;;
";
  close_out o;
  command "ocaml -init %s" tmp
    
let () =
  add_help "setup" "Run oasis setup + customizations";
  add_help "setup-clean" "Really clean oasis-generated files";
  add_help "clean all" "Run make clean and setup-clean";
  add_help "configure [ARGS]" "Run ocaml setup.ml -configure ARGS";
  add_help "{build,make} [ARGS]" "Run make ARGS";
  add_help "install" "Force re-installation";
  add_help "top" "Run a toplevel with the latest built biocaml.cma";
  add_help "{test,tests}"  "Run the tests\n";
  match List.tl_exn (Array.to_list Sys.argv) with
  | [] -> usage stdout
  | "-help" :: _ | "--help" :: _ | "-h" :: _ | "help" :: _ -> help ()
  | "setup" :: [] -> setup ()
  | "setup-clean" :: [] -> setup_clean ()
  | "clean" :: "all" :: [] -> command "make clean"; setup_clean ()
  | "configure" :: l ->
    command "ocaml setup.ml -configure %s"
      (String.concat ~sep:" " (List.map l (sprintf "%S")))
  | "build" :: args
  | "make" :: args ->
    command "make %s" (String.concat ~sep:" " (List.map args (sprintf "%S")))
  | "install" :: [] ->
    command "ocamlfind remove biocaml";
    command "ocaml setup.ml -reinstall";
  | "top" :: [] -> ocaml_toplevel ()
  | "test"  :: [] | "tests" :: [] -> command "ocaml setup.ml -test"
  | h :: _ -> eprintf "Cannot understand %s\n" h; usage stderr

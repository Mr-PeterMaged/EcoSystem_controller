import 'dart:io';
void main() {
  print("Hello world 1");
  print('Hello World 2');
  print('Hassan \'s laptop');
  print('Hassan');
  print('"');
  print("'");

  print("Hassan\'s age = ${5+14}");
  print("Hassan\'age\' = ${5+14}");



var student_result=gradeStudent(90);
print(student_result);

}

String gradeStudent(int grade){
if(grade>=90){
  return "Excellent";
}else if(grade>=80) {
  return "Good";
}else if(grade>=70){
  return "Pass";
}else {
return "fail";

}

}
  /*
\\ ---> prints:{\}
\' ---> prints:{'}
\$ ---> prints:{$}
\" ---> prints:{"}
\n ---> new line
\t ---> makes Tab
\b ---> backspace(removes the character before it: asd\b --> removes 'd')
\r --->  removes everything before it (asdf\r name , removes-->'asdf')
\"\" ---> prints double qoutes{""} inside double qoutes{""}(\"MyName\" prints --> "MyName")
\'\' ---> just like the double qoutes
print('"'); output--> "
print("'"); output--> '
 */

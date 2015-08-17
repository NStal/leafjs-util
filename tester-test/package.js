(function(){var style = document.createElement('style');style.setAttribute('data-debug-path',"path");style.innerHTML = "body,html{\n    background-color:red;\n    width:100%;\n    height:100%;\n}";document.head.appendChild(style)})();;;
(function() {
  window.other = {
    value: "otherValue"
  };

}).call(this);
;;;
window.test = {value:"testValue"}
;;;
(function() {
  console.log(other.value, "should be 'otherValue'");

  console.log(test.value, "should be 'testValue'");

  console.log("background should be red");

  console.log(template, "should be templateValue");

}).call(this);


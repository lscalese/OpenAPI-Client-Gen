Class dc.openapi.client.api.cspdemo Extends %CSP.Page
{

ClassMethod OnPage() As %Status
{
    &html<
        <!doctype html>
        <html lang="en">
        <head>
            <!-- Required meta tags -->
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">

            <!-- Bootstrap CSS -->
            <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css" integrity="sha384-Vkoo8x4CGsO3+Hhxv8T/Q5PaXtkKtu6ug5TOeNV6gBiFeWPGFN9MuhOf23Q9Ifjh" crossorigin="anonymous">
            <title>IRIS Production Generator</title>
        </head>
        <body onload="">
            <nav class="navbar navbar-dark bg-dark">
                <span class="navbar-brand mb-0 h1">IRIS Production Generator (1.0.2)</span>
                <ul class="navbar-nav mr-auto mt-2 mt-lg-0">
                    <li class="nav-item active">
                    <a class="nav-link" href="https://github.com/lscalese/OpenAPI-Client-Gen">Github</a>
                </li>
                </ul>   
                
            </nav>
            &nbsp;<br/>
            <div class="container">

                <div class="form-group">
                    &nbsp;<br/>
                    <label for="appName">Application package name</label>
                    <input type="text" class="form-control" id="appName"  placeholder="petshop">
                </div>
               
               
                <div class="form-group">
                    &nbsp;<br/>
                    <label for="spec">Swagger 2.0 specification</label>
                    <textarea class="form-control" id="spec" rows="20" placeholder="copy/paste your swagger 2.0 specification in json format or the specification URL."></textarea>
                </div>

                 <button type="button" class="btn btn-primary" onclick="generate();">Submit</button>
                
                 <div class="form-group">
                    &nbsp;<br/>
                    <label for="spec">Generated class</label>
                    <textarea class="form-control" id="generatedClass" rows="20" placeholder="" readonly></textarea>
                </div>
            </div>

            
            
            <!-- Optional JavaScript -->
            <!-- jQuery first, then Popper.js, then Bootstrap JS -->
            <script src="https://code.jquery.com/jquery-3.4.1.min.js" crossorigin="anonymous"></script>
            <script src="https://cdn.jsdelivr.net/npm/popper.js@1.16.0/dist/umd/popper.min.js" integrity="sha384-Q6E9RHvbIyZFJoft+2mJbHaEWldlvI9IOYy5n3zV9zzTtmI3UksdQRVvoxMfooAo" crossorigin="anonymous"></script>
            <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/js/bootstrap.min.js" integrity="sha384-wfSDF2E50Y2D1uUdj0O3uMBJnjuUD4Ih7YwaYd1iqfktj0Uod8GCExl3Og8ifwB6" crossorigin="anonymous"></script>
    >
    Do ..writeJS()
    &html<
        </body>
        </html>
    >
    Return $$$OK
}

ClassMethod writeJS() As %Status
{
    Set tSc = $$$OK
    Write "<script type=""text/javascript"">"
    &js<

        /*function createAndOpenFile(){
            var stupidExample = '<?xml version="1.0" encoding="utf-8"?><aTag>something</aTag>';
            document.open('data:Application/octet-stream,' + encodeURIComponent(stupidExample));
        }*/

        var basicDefaultAuth = true;
        
        function generate() {
            jQuery.ajax({
                type: "POST",
                url: "/swaggerclientgen/api/interopclasses/"+jQuery("#appName").val(),
                processData: false,
                contentType: 'application/json',
                data: jQuery("#spec").val(),
                async: true,
                success: function (data){
                    var s = new XMLSerializer();
                    var classStr = s.serializeToString(data);
                    jQuery("#generatedClass").val(classStr);
                    downloadFile(classStr, jQuery("#appName").val()+".xml", "text/xml")
                },
                error: function(jqXHR, textStatus, errorThrown ) {
                    alert(textStatus);
                    if (jqXHR.status==401) {
                        basicDefaultAuth = false; // force browser prompt for next query
                    }
                },
                beforeSend: function (xhr) {
                    if (basicDefaultAuth) {
                        ///
                    }
                }
            });
        }


        function downloadFile(data, name, type) {
            var anchor = document.createElement('a')
            anchor.href = window.URL.createObjectURL(new Blob([data], { type }));
            anchor.download = name
            anchor.click()
        }

        

        
    >
    Write "</script>"
    Return tSc
}

}

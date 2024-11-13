module tb ();
    logic [31:0] a, b, sum;

    adder DUT(.*); //instantiate the amazing adder

    initial begin
	$dumpon;
	$dumpall;
    	a = 1;
    	b = 2;
    	#1;
    	assert (sum == 3) else $fatal(1, "Error");
    	$display("TB passed, adder ready to use in production");
	a = 2;
	b = 3;
	$dumpoff;
    end
endmodule : tb

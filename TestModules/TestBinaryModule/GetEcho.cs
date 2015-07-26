using System.Management.Automation;

namespace TestBinaryModule
{
    [Cmdlet("Get", "Echo")]
    public class GetEcho : PSCmdlet
    {
        [Parameter(Mandatory=true, Position=0)]
        public object InputObject { get; set; }

        protected override void BeginProcessing()
        {
            WriteObject(InputObject);
        }

    }
}

// @ts-nocheck
import { useState, useEffect } from 'react';
import mermaid from 'mermaid';

const MermaidRenderer = (awsData) => {
  const [data, setData] = useState(null);
  const [mermaidCode, setMermaidCode] = useState('');

  // Function to generate Mermaid markup from AWS data
  const generateMermaidMarkup = (awsData) => {
    let markup = 'graph TD\n';
    
    // Add VPC
    const vpc = awsData.vpc_configuration.VPCs[0];
    markup += `    vpc[VPC: ${vpc.VpcId}<br/>CIDR: ${vpc.CidrBlock}]\n\n`;

    // Add Subnets
    awsData.vpc_configuration.Subnets.forEach((subnet, index) => {
      markup += `    subnet${index}[Subnet: ${subnet.SubnetId}<br/>AZ: ${subnet.AvailabilityZone}<br/>CIDR: ${subnet.CidrBlock}]\n`;
      markup += `    vpc --> subnet${index}\n`;
    });
    markup += '\n';

    // Add Security Groups
    const securityGroups = new Map();
    awsData.security_groups.forEach((sg, index) => {
      securityGroups.set(sg.GroupId, `sg${index}`);
      markup += `    sg${index}[SG: ${sg.GroupName}]\n`;
    });
    markup += '\n';

    // Add EC2 Instances and their relationships
    awsData.ec2_instances.forEach((instance, index) => {
      markup += `    ec2_${index}[EC2: ${instance.Tags[0]?.Value || instance.InstanceId}<br/>${instance.InstanceType}]\n`;
      
      // Connect to subnet
      const subnetIndex = awsData.vpc_configuration.Subnets.findIndex(s => s.SubnetId === instance.SubnetId);
      markup += `    subnet${subnetIndex} --> ec2_${index}\n`;
      
      // Connect to security groups
      instance.SecurityGroups.forEach(sg => {
        const sgId = securityGroups.get(sg.GroupId);
        markup += `    ec2_${index} --> ${sgId}\n`;
      });
    });

    // Add styling
    markup += '\n    %% Styling\n';
    markup += '    classDef vpc fill:#FFD700,stroke:#B8860B,stroke-width:2px\n';
    markup += '    classDef subnet fill:#98FB98,stroke:#228B22,stroke-width:2px\n';
    markup += '    classDef ec2 fill:#87CEEB,stroke:#4682B4,stroke-width:2px\n';
    markup += '    classDef sg fill:#FFA07A,stroke:#CD5C5C,stroke-width:2px\n\n';

    // Apply classes
    markup += '    class vpc vpc\n';
    markup += `    class ${Array.from({ length: awsData.vpc_configuration.Subnets.length }, (_, i) => 'subnet' + i).join(',')} subnet\n`;
    markup += `    class ${Array.from({ length: awsData.ec2_instances.length }, (_, i) => 'ec2_' + i).join(',')} ec2\n`;
    markup += `    class ${Array.from({ length: awsData.security_groups.length }, (_, i) => 'sg' + i).join(',')} sg\n`;

    return markup;
  };

  useEffect(() => {
    mermaid.initialize({ startOnLoad: true });
    // document.getElementById(id)?.removeAttribute("data-processed");
    mermaid.contentLoaded();
    setData(awsData.awsData);
    const markup = generateMermaidMarkup(awsData.awsData);
    setMermaidCode(markup);

  }, []);

  if (!data) return <div>Loading...</div>;

  return (
    <div className="p-4 bg-white rounded-lg shadow">
      <div className="mb-4">
        <div className="mermaid">
            {mermaidCode}
        </div>
      </div>
    </div>
  );
};

export default MermaidRenderer;


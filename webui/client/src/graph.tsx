// @ts-nocheck
import { useEffect } from "react";
import { Network } from "vis-network";
import { DataSet } from "vis-data";

const AWSInfraVisualization = ({ awsData }) => {
  useEffect(() => {
    const nodes = [];
    const edges = [];

    // Add VPCs
    awsData.vpc_configuration.VPCs.forEach((vpc, index) => {
      nodes.push({
        id: `vpc-${index}`,
        label: `VPC\n${vpc.VpcId}`,
        shape: "box",
        color: "#FF5733",
      });
    });

    // Add EC2 Instances
    awsData.ec2_instances.forEach((instance, index) => {
      nodes.push({
        id: `ec2-${index}`,
        label: `EC2\n${instance.InstanceId}`,
        shape: "ellipse",
        color: "#33C3FF",
      });
      edges.push({ from: `vpc-${0}`, to: `ec2-${index}` }); // Connect to the first VPC as an example
    });

    // Add Security Groups
    awsData.security_groups.forEach((group, index) => {
      nodes.push({
        id: `sg-${index}`,
        label: `SG\n${group.GroupId}`,
        shape: "diamond",
        color: "#7D3C98",
      });
      awsData.ec2_instances.forEach((instance, instanceIndex) => {
        instance.SecurityGroups.forEach((instanceGroup) => {
          if (instanceGroup.GroupId === group.GroupId) {
            edges.push({ from: `sg-${index}`, to: `ec2-${instanceIndex}` });
          }
        });
      });
    });

    // Add Subnets
    awsData.vpc_configuration.Subnets.forEach((subnet, index) => {
      nodes.push({
        id: `subnet-${index}`,
        label: `Subnet\n${subnet.SubnetId}`,
        shape: "hexagon",
        color: "#F1C40F",
      });
      edges.push({ from: `vpc-${0}`, to: `subnet-${index}` }); // Connect to the first VPC as an example
    });

    const container = document.getElementById("network");
    const data = {
      nodes: new DataSet(nodes),
      edges: new DataSet(edges),
    };
    const options = {
      physics: {
        enabled: true,
        solver: "barnesHut",
        barnesHut: {
            gravitationalConstant: -2000, // Nodes repel each other more
            centralGravity: 0.3,
            springLength: 150, // Length of the edges
            springConstant: 0.04,
        },
      },
      layout: {
        hierarchical: {
          direction: "UD",
          sortMethod: "directed",
        //   nodeSpacing: 200, // Increase spacing between nodes
        //   levelSeparation: 300, // Increase spacing between levels
        },
      },
      nodes: {
        font: { size: 14 },
        borderWidth: 2,
      },
      edges: {
        arrows: { to: { enabled: true } },
        color: "#848484",
      },
    };
    new Network(container, data, options);
  }, [awsData]);

  return <div id="network" style={{ height: "400px" }}></div>;
};

export default AWSInfraVisualization;

// @ts-nocheck
import { useEffect, useState, useRef } from 'react';
import './App.css'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Accordion, AccordionItem, AccordionTrigger, AccordionContent } from "@/components/ui/accordion";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Server, Shield, Users, Network } from 'lucide-react';
import axios from 'axios';
import AWSInfraVisualization from "./graph";
import MermaidRenderer from "./mermaid";

const LoadingSpinner = () => (
  <div className="flex justify-center items-center py-4">
    <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-gray-400"></div>
  </div>
);



function App() {
  const [data, setData] = useState(null);
  const [faq, setFaq] = useState<any>({});
  const [messages, setMessages] = useState<any[]>([]);
  const [userMessage, setUserMessage] = useState("");
  const bottomRef = useRef<HTMLDivElement>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const openModal = () => setIsModalOpen(true);
  const closeModal = () => setIsModalOpen(false);

  useEffect(() => {
    const loadData = async () => {
      try {
        const response = await axios.get('/api/data');
        
        setData(response.data);

        const savedFaq = localStorage.getItem('faq');
        if (savedFaq) {
          setFaq(JSON.parse(savedFaq)); // Load the saved chat history
        } else {
          axios.get('/api/faq')
          .then((response) => {
            setFaq(response.data.faq);
            localStorage.setItem('faq', JSON.stringify(response.data.faq));
          });
        }
      } catch (error) {
        console.error('Error loading data:', error);
      }
    };
    loadData();
  }, []);

  // Close modal on esc press
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape" && isModalOpen) {
        closeModal(); // Close modal when Escape is pressed
      }
    };

    // Add event listener when the component is mounted
    document.addEventListener("keydown", handleKeyDown);

    // Clean up event listener when the component is unmounted
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [isModalOpen]);

  // Load chat history from localStorage on component mount
  useEffect(() => {
    const savedMessages = localStorage.getItem('chatHistory');
    if (savedMessages) {
      setMessages(JSON.parse(savedMessages)); // Load the saved chat history
    } else {
      setMessages([{ sender: "bot", text: "Hi! How can I help you?" }])
    }
  }, []);

  // Save chat history to localStorage whenever messages change
  useEffect(() => {
    if (messages.length > 0) {
      localStorage.setItem('chatHistory', JSON.stringify(messages));
    }
  }, [messages]);

  // Scroll to the bottom whenever the page content changes
  useEffect(() => {
    window.scrollTo(0, document.body.scrollHeight); // Scroll to the bottom of the page
  }, [messages]); // Depend on `messages` so it runs when new messages are added
  // Automatically scroll to the bottom when messages change
  useEffect(() => {
    if (bottomRef.current) {
      bottomRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && userMessage.trim() !== '') {
      handleSend(); // Trigger message send when Enter is pressed
    }
  };


  const handleSend = async () => {
    if (!userMessage.trim()) return;

    // Add user message to the chat
    setMessages((prev) => [...prev, { sender: "user", text: userMessage }]);
    setLoading(true);
    const response = await axios.get(`/api/question?message=${userMessage}`);
    setUserMessage("");

    // Mock bot response for now
    setTimeout(() => {
      setMessages((prev) => [
        ...prev,
        { sender: "bot", text: response.data.response }
      ]);
      setLoading(false);
    }, 1000);
  };

  if (!data) return <div className="p-4">Loading...</div>;

  return (
    // Tabs
    <div className="p-4 space-y-4 bg-gray-50 min-h-screen">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold">AWS CMDB Dashboard</h1>
        <div className="flex justify-center gap-6 text-sm text-gray-600">
          <span>Account: {data.account_id}</span>
          <span>Region: {data.region}</span>
          <span>Last Updated: {new Date(data.timestamp).toLocaleString()}</span>
        </div>
      </header>

      <Tabs defaultValue="instances">
        <TabsList className="bg-white">
          <TabsTrigger value="instances" className="flex items-center gap-2">
            <Server className="w-4 h-4" />
            EC2 Instances
          </TabsTrigger>
          <TabsTrigger value="security" className="flex items-center gap-2">
            <Shield className="w-4 h-4" />
            Security Groups
          </TabsTrigger>
          <TabsTrigger value="iam" className="flex items-center gap-2">
            <Users className="w-4 h-4" />
            IAM
          </TabsTrigger>
          <TabsTrigger value="vpc" className="flex items-center gap-2">
            <Network className="w-4 h-4" />
            VPC
          </TabsTrigger>
        </TabsList>

        <TabsContent value="instances">
          <Card>
            <CardHeader>
              <CardTitle>EC2 Instances ({data.ec2_instances.length})</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="max-h-[600px] overflow-auto">
                <table className="w-full border-collapse bg-white">
                  <thead className="bg-gray-50 sticky top-0">
                    <tr>
                      <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Name</th>
                      <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Instance ID</th>
                      <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Type</th>
                      <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">State</th>
                      <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Private IP</th>
                      <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Public IP</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200">
                    {data.ec2_instances.map((instance) => (
                      <tr key={instance.InstanceId} className="hover:bg-gray-50">
                        <td className="px-4 py-2 text-sm">{instance.Tags?.find(t => t.Key === 'Name')?.Value || '-'}</td>
                        <td className="px-4 py-2 text-sm font-mono">{instance.InstanceId}</td>
                        <td className="px-4 py-2 text-sm">{instance.InstanceType}</td>
                        <td className="px-4 py-2 text-sm">
                          <span className={`px-2 py-1 rounded-full text-xs ${
                            instance.State === 'running' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                          }`}>
                            {instance.State}
                          </span>
                        </td>
                        <td className="px-4 py-2 text-sm font-mono">{instance.PrivateIpAddress}</td>
                        <td className="px-4 py-2 text-sm font-mono">{instance.PublicIpAddress}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="security">
          <Card>
            <CardHeader>
              <CardTitle>Security Groups ({data.security_groups.length})</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="max-h-[600px] overflow-auto">
                <table className="w-full border-collapse bg-white">
                  <thead className="bg-gray-50 sticky top-0">
                    <tr>
                      <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Group Name</th>
                      <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Group ID</th>
                      <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">VPC ID</th>
                      <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Description</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200">
                    {data.security_groups.map((sg) => (
                      <tr key={sg.GroupId} className="hover:bg-gray-50">
                        <td className="px-4 py-2 text-sm">{sg.GroupName}</td>
                        <td className="px-4 py-2 text-sm font-mono">{sg.GroupId}</td>
                        <td className="px-4 py-2 text-sm font-mono">{sg.VpcId}</td>
                        <td className="px-4 py-2 text-sm">{sg.Description}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="iam">
          <div className="grid grid-cols-2 gap-4">
            <Card>
              <CardHeader>
                <CardTitle>IAM Users ({data.iam_configuration.Users.length})</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="max-h-[400px] overflow-auto">
                  <table className="w-full border-collapse bg-white">
                    <thead className="bg-gray-50 sticky top-0">
                      <tr>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Username</th>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">User ID</th>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Created</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-200">
                      {data.iam_configuration.Users.map((user) => (
                        <tr key={user.UserId} className="hover:bg-gray-50">
                          <td className="px-4 py-2 text-sm">{user.UserName}</td>
                          <td className="px-4 py-2 text-sm font-mono">{user.UserId}</td>
                          <td className="px-4 py-2 text-sm">{new Date(user.CreateDate).toLocaleDateString()}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>IAM Roles ({data.iam_configuration.Roles.length})</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="max-h-[400px] overflow-auto">
                  <table className="w-full border-collapse bg-white">
                    <thead className="bg-gray-50 sticky top-0">
                      <tr>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Role Name</th>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Role ID</th>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Created</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-200">
                      {data.iam_configuration.Roles.map((role) => (
                        <tr key={role.RoleId} className="hover:bg-gray-50">
                          <td className="px-4 py-2 text-sm">{role.RoleName}</td>
                          <td className="px-4 py-2 text-sm font-mono">{role.RoleId}</td>
                          <td className="px-4 py-2 text-sm">{new Date(role.CreateDate).toLocaleDateString()}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="vpc">
          <div className="grid gap-4">
            <Card>
              <CardHeader>
                <CardTitle>VPC Configuration</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="max-h-[300px] overflow-auto">
                  <table className="w-full border-collapse bg-white">
                    <thead className="bg-gray-50 sticky top-0">
                      <tr>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">VPC ID</th>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">CIDR Block</th>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">State</th>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Default</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-200">
                      {data.vpc_configuration.VPCs.map((vpc) => (
                        <tr key={vpc.VpcId} className="hover:bg-gray-50">
                          <td className="px-4 py-2 text-sm font-mono">{vpc.VpcId}</td>
                          <td className="px-4 py-2 text-sm">{vpc.CidrBlock}</td>
                          <td className="px-4 py-2 text-sm">{vpc.State}</td>
                          <td className="px-4 py-2 text-sm">{vpc.IsDefault ? 'Yes' : 'No'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Subnets</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="max-h-[300px] overflow-auto">
                  <table className="w-full border-collapse bg-white">
                    <thead className="bg-gray-50 sticky top-0">
                      <tr>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Subnet ID</th>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">CIDR Block</th>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">AZ</th>
                        <th className="px-4 py-2 text-left text-sm font-medium text-gray-500">Available IPs</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-200">
                      {data.vpc_configuration.Subnets.map((subnet) => (
                        <tr key={subnet.SubnetId} className="hover:bg-gray-50">
                          <td className="px-4 py-2 text-sm font-mono">{subnet.SubnetId}</td>
                          <td className="px-4 py-2 text-sm">{subnet.CidrBlock}</td>
                          <td className="px-4 py-2 text-sm">{subnet.AvailabilityZone}</td>
                          <td className="px-4 py-2 text-sm">{subnet.AvailableIpAddressCount}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>
      {/* faq */}
      <div className="max-w-2xl mx-auto p-4">
        <h2 className="text-2xl font-bold mb-4">AI FAQ</h2>
        {faq !== null ? (
          
        <Accordion type="single" collapsible>
          {Object.entries(faq).map(([question, response], index) => (
            <AccordionItem key={index} value={`faq-${index}`}>
              <AccordionTrigger>{question}</AccordionTrigger>
              <AccordionContent className="text-left">{response}</AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>

        ) : <LoadingSpinner />}
        
      </div>
      {/* Chat */}
      <div className="max-w-2xl mx-auto p-4">
        <h2 className="text-2xl font-bold mb-4">AI CHAT</h2>
        <Card className="h-auto overflow-y-auto p-4" style={{ height: '460px' }}>
          <CardContent>
            <div className="space-y-4">
              {messages.map((message, index) => (
                <div
                  key={index}
                  className={`p-2 rounded-lg ${
                    message.sender === "user"
                      ? "bg-blue-500 text-white self-end"
                      : "bg-gray-200 text-gray-900"
                  }`}
                  style={{
                    maxWidth: "100%",
                    alignSelf: message.sender === "user" ? "flex-end" : "flex-start"
                  }}
                >
                  {message.text}
                </div>
              ))}
              {/* Display loading spinner if chat is waiting for response */}
              {loading && <LoadingSpinner />}
              {/* Reference to the last message for automatic scroll */}
            <div ref={bottomRef} />
            </div>
          </CardContent>
        </Card>
        <div className="flex items-center mt-4 space-x-2">
          <Input
            type="text"
            value={userMessage}
            onChange={(e) => setUserMessage(e.target.value)}
            placeholder="Type your message..."
            className="flex-1"
            onKeyDown={handleKeyDown}
          />
          <Button onClick={handleSend} disabled={userMessage.trim() === ''}>Send</Button>
        </div>
      </div>
      {/* Diagrams */}
      <div className="max-w-2xl mx-auto p-4">
        {/* <h2 className="text-2xl font-bold mb-4">AWS infrastructure visualization</h2>
        <Button onClick={openModal}>Open diagrams</Button> */}
        {isModalOpen && (
          <div
            style={{
              position: "fixed",
              top: 0,
              left: 0,
              width: "100%",
              height: "100%",
              backgroundColor: "rgba(0, 0, 0, 0.5)",
              display: "flex",
              justifyContent: "center",
              alignItems: "center",
              zIndex: 1000,
            }}
          >
            <div
              style={{
                backgroundColor: "white",
                padding: "20px",
                borderRadius: "8px",
                width: "80%",
                height: "80%",
                position: "relative",
                overflow: "hidden",
              }}
            >
              <Button
                  onClick={closeModal}
                  variant="destructive"
                  className="absolute top-2 right-2 w-8 h-8 flex items-center justify-center rounded-full bg-red-500 text-white"
                >
                X
              </Button>
              <AWSInfraVisualization awsData={data} />
              <MermaidRenderer awsData={data} />
            </div>
          </div>
        )}
        
        
      </div>
    </div>
  );
};

export default App